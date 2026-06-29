import org.apache.rocketmq.client.producer.DefaultMQProducer;
import org.apache.rocketmq.client.producer.SendResult;
import org.apache.rocketmq.client.producer.SendStatus;
import org.apache.rocketmq.client.consumer.DefaultMQPushConsumer;
import org.apache.rocketmq.client.consumer.listener.*;
import org.apache.rocketmq.common.message.Message;
import org.apache.rocketmq.common.message.MessageExt;
import org.apache.rocketmq.common.consumer.ConsumeFromWhere;

import java.io.*;
import java.nio.charset.StandardCharsets;
import java.text.SimpleDateFormat;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.*;

/**
 * RocketMQ DLedger failover probe.
 *
 * Producer threads send monotonically-sequenced messages (each carries a global
 * seq id + unique key) to a topic whose queues span both DLedger broker groups.
 * A push consumer reads them back and records every seq it has seen, enabling
 * loss / duplicate / out-of-order detection (RPO/ordering verification).
 *
 * Per-second metrics are written to a CSV; lifecycle events to an events log.
 *
 * Args (all optional, via -D system properties):
 *   namesrv   (NAMESRV_ADDR)              default from env
 *   topic     test topic                  default FailoverTopic
 *   threads   producer threads            default 8
 *   rate      target msgs/sec (total)     default 2000
 *   size      payload bytes               default 512
 *   seconds   total run seconds           default 180
 *   outdir    output directory            default ./run
 */
public class FailoverProbe {
    static volatile boolean running = true;

    // counters
    static final AtomicLong sentOk = new AtomicLong();
    static final AtomicLong sentFail = new AtomicLong();
    static final AtomicLong consumed = new AtomicLong();
    static final AtomicLong duplicate = new AtomicLong();
    static final AtomicLong outOfOrder = new AtomicLong();
    static final LongAdder latSumUs = new LongAdder();
    static final AtomicLong latMaxUs = new AtomicLong();

    // seq -> sent (true once send returns OK). consumed marks seen.
    static final ConcurrentHashMap<Long, Boolean> sentSeqs = new ConcurrentHashMap<>();
    static final ConcurrentHashMap<Long, Boolean> seenSeqs = new ConcurrentHashMap<>();
    // per-queue last seq for ordering check (broker+queueId -> last seq)
    static final ConcurrentHashMap<String, Long> lastSeqPerQueue = new ConcurrentHashMap<>();

    static long P(String k, long def) {
        String v = System.getProperty(k);
        return v == null ? def : Long.parseLong(v);
    }
    static String Ps(String k, String def) {
        String v = System.getProperty(k);
        return v == null ? def : v;
    }

    public static void main(String[] args) throws Exception {
        String namesrv = Ps("namesrv", System.getenv("NAMESRV_ADDR"));
        String topic   = Ps("topic", "FailoverTopic");
        int threads    = (int) P("threads", 8);
        int rate       = (int) P("rate", 2000);
        int size       = (int) P("size", 512);
        int seconds    = (int) P("seconds", 180);
        String outdir  = Ps("outdir", "run");
        new File(outdir).mkdirs();

        final SimpleDateFormat ts = new SimpleDateFormat("HH:mm:ss.SSS");

        PrintWriter csv = new PrintWriter(new FileWriter(outdir + "/metrics.csv"));
        csv.println("epoch_ms,wallclock,sent_ok,sent_fail,consumed,qps,fail_ps,consume_ps,p_avg_ms,p_max_ms,dup_total,ooo_total");
        PrintWriter events = new PrintWriter(new FileWriter(outdir + "/events.log"));
        events.printf("%d %s PROBE_START namesrv=%s topic=%s threads=%d rate=%d size=%d seconds=%d%n",
                System.currentTimeMillis(), ts.format(new Date()), namesrv, topic, threads, rate, size, seconds);
        events.flush();

        // ---- consumer ----
        DefaultMQPushConsumer consumer = new DefaultMQPushConsumer("probe_consumer_grp");
        consumer.setNamesrvAddr(namesrv);
        consumer.setConsumeFromWhere(ConsumeFromWhere.CONSUME_FROM_LAST_OFFSET);
        consumer.subscribe(topic, "*");
        consumer.setConsumeMessageBatchMaxSize(32);
        consumer.registerMessageListener((MessageListenerConcurrently) (msgs, ctx) -> {
            for (MessageExt m : msgs) {
                try {
                    String body = new String(m.getBody(), StandardCharsets.UTF_8);
                    int idx = body.indexOf(':');
                    long seq = Long.parseLong(idx > 0 ? body.substring(0, idx) : body.trim());
                    consumed.incrementAndGet();
                    if (seenSeqs.putIfAbsent(seq, Boolean.TRUE) != null) {
                        duplicate.incrementAndGet();
                    }
                    String qk = m.getBrokerName() + "#" + m.getQueueId();
                    Long last = lastSeqPerQueue.get(qk);
                    if (last != null && seq < last) outOfOrder.incrementAndGet();
                    lastSeqPerQueue.put(qk, seq);
                } catch (Exception e) { /* ignore parse */ }
            }
            return ConsumeConcurrentlyStatus.CONSUME_SUCCESS;
        });
        consumer.start();
        events.printf("%d %s CONSUMER_STARTED%n", System.currentTimeMillis(), ts.format(new Date()));
        events.flush();

        // ---- producer ----
        DefaultMQProducer producer = new DefaultMQProducer("probe_producer_grp");
        producer.setNamesrvAddr(namesrv);
        producer.setSendMsgTimeout(3000);
        producer.setRetryTimesWhenSendFailed(2);
        producer.start();
        events.printf("%d %s PRODUCER_STARTED%n", System.currentTimeMillis(), ts.format(new Date()));
        events.flush();

        final AtomicLong seqGen = new AtomicLong(0);
        final byte[] pad = new byte[Math.max(0, size - 40)];
        Arrays.fill(pad, (byte) 'x');
        final String padStr = new String(pad, StandardCharsets.UTF_8);

        // rate limiter: tokens per 100ms window per total
        final int perTick = Math.max(1, rate / 10);
        ExecutorService pool = Executors.newFixedThreadPool(threads);
        final Semaphore permits = new Semaphore(0);

        // token dispenser
        ScheduledExecutorService sched = Executors.newScheduledThreadPool(2);
        sched.scheduleAtFixedRate(() -> {
            permits.drainPermits();
            permits.release(perTick);
        }, 0, 100, TimeUnit.MILLISECONDS);

        for (int t = 0; t < threads; t++) {
            pool.submit(() -> {
                while (running) {
                    try {
                        if (!permits.tryAcquire(50, TimeUnit.MILLISECONDS)) continue;
                        long seq = seqGen.incrementAndGet();
                        String key = "k" + seq;
                        String payload = seq + ":" + padStr;
                        Message msg = new Message(topic, "T", key, payload.getBytes(StandardCharsets.UTF_8));
                        long t0 = System.nanoTime();
                        SendResult r = producer.send(msg);
                        long us = (System.nanoTime() - t0) / 1000;
                        if (r != null && r.getSendStatus() == SendStatus.SEND_OK) {
                            sentOk.incrementAndGet();
                            sentSeqs.put(seq, Boolean.TRUE);
                            latSumUs.add(us);
                            latMaxUs.accumulateAndGet(us, Math::max);
                        } else {
                            sentFail.incrementAndGet();
                        }
                    } catch (Throwable e) {
                        sentFail.incrementAndGet();
                    }
                }
            });
        }

        // per-second sampler
        long endAt = System.currentTimeMillis() + seconds * 1000L;
        long prevOk = 0, prevFail = 0, prevCons = 0;
        while (System.currentTimeMillis() < endAt) {
            Thread.sleep(1000);
            long ok = sentOk.get(), fail = sentFail.get(), cons = consumed.get();
            long qps = ok - prevOk, fps = fail - prevFail, cps = cons - prevCons;
            long sumUs = latSumUs.sumThenReset();
            long maxUs = latMaxUs.getAndSet(0);
            double avgMs = qps > 0 ? (sumUs / 1000.0) / qps : 0;
            double maxMs = maxUs / 1000.0;
            long now = System.currentTimeMillis();
            csv.printf("%d,%s,%d,%d,%d,%d,%d,%d,%.3f,%.3f,%d,%d%n",
                    now, ts.format(new Date(now)), ok, fail, cons, qps, fps, cps, avgMs, maxMs,
                    duplicate.get(), outOfOrder.get());
            csv.flush();
            prevOk = ok; prevFail = fail; prevCons = cons;
        }

        running = false;
        pool.shutdown();
        pool.awaitTermination(10, TimeUnit.SECONDS);
        sched.shutdownNow();
        producer.shutdown();
        // allow consumer to drain
        Thread.sleep(8000);
        consumer.shutdown();

        // final reconciliation: which sent seqs were never seen = lost
        long lost = 0;
        for (Long s : sentSeqs.keySet()) if (!seenSeqs.containsKey(s)) lost++;

        events.printf("%d %s PROBE_END sent_ok=%d sent_fail=%d consumed=%d unique_seen=%d lost=%d duplicate=%d out_of_order=%d%n",
                System.currentTimeMillis(), ts.format(new Date()),
                sentOk.get(), sentFail.get(), consumed.get(), seenSeqs.size(), lost, duplicate.get(), outOfOrder.get());
        events.flush(); events.close();

        PrintWriter summary = new PrintWriter(new FileWriter(outdir + "/summary.txt"));
        summary.printf("sent_ok=%d%n", sentOk.get());
        summary.printf("sent_fail=%d%n", sentFail.get());
        summary.printf("consumed_total=%d%n", consumed.get());
        summary.printf("unique_seen=%d%n", seenSeqs.size());
        summary.printf("lost=%d%n", lost);
        summary.printf("duplicate=%d%n", duplicate.get());
        summary.printf("out_of_order=%d%n", outOfOrder.get());
        summary.close();
        csv.close();

        System.out.println("DONE sent_ok=" + sentOk.get() + " fail=" + sentFail.get()
                + " seen=" + seenSeqs.size() + " lost=" + lost + " dup=" + duplicate.get()
                + " ooo=" + outOfOrder.get());
    }
}
