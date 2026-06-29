import org.apache.rocketmq.client.producer.DefaultMQProducer;
import org.apache.rocketmq.client.producer.SendResult;
import org.apache.rocketmq.client.producer.SendStatus;
import org.apache.rocketmq.common.message.Message;
import org.apache.rocketmq.client.consumer.DefaultMQPushConsumer;
import org.apache.rocketmq.client.consumer.listener.MessageListenerConcurrently;
import org.apache.rocketmq.client.consumer.listener.ConsumeConcurrentlyStatus;
import org.apache.rocketmq.client.consumer.listener.ConsumeConcurrentlyContext;
import org.apache.rocketmq.common.message.MessageExt;
import org.apache.rocketmq.common.consumer.ConsumeFromWhere;

import java.io.FileWriter;
import java.io.PrintWriter;
import java.nio.charset.StandardCharsets;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Date;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentLinkedQueue;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicLong;

/**
 * RocketMQ DLedger failover probe (single file, official rocketmq-client 4.9.7).
 * Modes:
 *   produce  <namesrv> <topic> <threads> <durationSec> <ratePerThreadPerSec> <csvPath> <runId> [retries]
 *   verify   <namesrv> <topic> <runId> <timeoutNoMsgSec>
 * If [retries] > 0, client send retries are enabled (retryTimesWhenSendFailed=retries,
 * retryAnotherBrokerWhenNotStoreOK=true) to measure user-visible interruption.
 */
public class Probe {
    static final SimpleDateFormat WALL = new SimpleDateFormat("HH:mm:ss.SSS");

    public static void main(String[] args) throws Exception {
        if (args.length == 0) { System.err.println("need mode"); System.exit(2); }
        String mode = args[0];
        if ("produce".equals(mode)) produce(args);
        else if ("verify".equals(mode)) verify(args);
        else { System.err.println("unknown mode " + mode); System.exit(2); }
    }

    static void produce(String[] a) throws Exception {
        String namesrv = a[1];
        String topic = a[2];
        int threads = Integer.parseInt(a[3]);
        int durationSec = Integer.parseInt(a[4]);
        int ratePerThread = Integer.parseInt(a[5]);
        String csvPath = a[6];
        String runId = a[7];
        int retries = (a.length > 8) ? Integer.parseInt(a[8]) : 0;

        final AtomicLong okTotal = new AtomicLong();
        final AtomicLong failTotal = new AtomicLong();
        final AtomicLong okSec = new AtomicLong();
        final AtomicLong failSec = new AtomicLong();
        final ConcurrentLinkedQueue<Long> latSec = new ConcurrentLinkedQueue<Long>();
        final ConcurrentHashMap<String, AtomicLong> errKinds = new ConcurrentHashMap<String, AtomicLong>();
        final AtomicBoolean running = new AtomicBoolean(true);

        DefaultMQProducer producer = new DefaultMQProducer("probe_producer_grp");
        producer.setNamesrvAddr(namesrv);
        producer.setSendMsgTimeout(3000);
        if (retries > 0) {
            producer.setRetryTimesWhenSendFailed(retries);            // enabled: measure user-visible interruption
            producer.setRetryTimesWhenSendAsyncFailed(retries);
            producer.setRetryAnotherBrokerWhenNotStoreOK(true);       // resend to a healthy broker group
        } else {
            producer.setRetryTimesWhenSendFailed(0);                  // raw failover, no client retry masking
            producer.setRetryTimesWhenSendAsyncFailed(0);
            producer.setRetryAnotherBrokerWhenNotStoreOK(false);
        }
        producer.start();
        System.out.println("PRODUCER started runId=" + runId + " retries=" + retries
                + " retryAnotherBroker=" + (retries > 0));

        // metrics reporter
        final PrintWriter csv = new PrintWriter(new FileWriter(csvPath, false));
        csv.println("epoch_ms,wall,sec,ok,fail,ok_total,fail_total,p50_ms,p99_ms,max_ms,err");
        csv.flush();
        final long t0 = System.currentTimeMillis();
        Thread reporter = new Thread(new Runnable() {
            public void run() {
                int sec = 0;
                while (running.get()) {
                    try { Thread.sleep(1000); } catch (InterruptedException e) { break; }
                    long ms = System.currentTimeMillis();
                    long ok = okSec.getAndSet(0);
                    long fl = failSec.getAndSet(0);
                    List<Long> lats = new ArrayList<Long>();
                    Long v;
                    while ((v = latSec.poll()) != null) lats.add(v);
                    Collections.sort(lats);
                    long p50 = pct(lats, 50), p99 = pct(lats, 99), mx = lats.isEmpty() ? 0 : lats.get(lats.size() - 1);
                    StringBuilder eb = new StringBuilder();
                    for (Map.Entry<String, AtomicLong> e : errKinds.entrySet()) {
                        if (eb.length() > 0) eb.append('|');
                        eb.append(e.getKey()).append(':').append(e.getValue().get());
                    }
                    sec++;
                    csv.println(ms + "," + WALL.format(new Date(ms)) + "," + sec + "," + ok + "," + fl + ","
                            + okTotal.get() + "," + failTotal.get() + "," + p50 + "," + p99 + "," + mx + "," + eb);
                    csv.flush();
                    System.out.println("[" + WALL.format(new Date(ms)) + "] sec=" + sec + " ok=" + ok + " fail=" + fl
                            + " okTotal=" + okTotal.get() + " p50=" + p50 + " p99=" + p99 + " max=" + mx + " err=" + eb);
                }
            }
        });
        reporter.setDaemon(true);
        reporter.start();

        List<Thread> ws = new ArrayList<Thread>();
        for (int i = 0; i < threads; i++) {
            final int tid = i;
            Thread w = new Thread(new Runnable() {
                public void run() {
                    long seq = 0;
                    long endAt = t0 + durationSec * 1000L;
                    long intervalNs = ratePerThread > 0 ? (1_000_000_000L / ratePerThread) : 0;
                    while (running.get() && System.currentTimeMillis() < endAt) {
                        long startBatch = System.nanoTime();
                        seq++;
                        String body = runId + ":" + tid + ":" + seq;
                        Message msg = new Message(topic, "p", body, body.getBytes(StandardCharsets.UTF_8));
                        msg.setKeys(tid + "-" + seq);
                        long s = System.nanoTime();
                        try {
                            SendResult r = producer.send(msg);
                            long lat = (System.nanoTime() - s) / 1_000_000L;
                            if (r != null && r.getSendStatus() == SendStatus.SEND_OK) {
                                okTotal.incrementAndGet(); okSec.incrementAndGet(); latSec.add(lat);
                            } else {
                                failTotal.incrementAndGet(); failSec.incrementAndGet();
                                bump(errKinds, r == null ? "NULL" : r.getSendStatus().name());
                            }
                        } catch (Throwable e) {
                            failTotal.incrementAndGet(); failSec.incrementAndGet();
                            bump(errKinds, e.getClass().getSimpleName());
                        }
                        if (intervalNs > 0) {
                            long elapsed = System.nanoTime() - startBatch;
                            long sleep = intervalNs - elapsed;
                            if (sleep > 0) { try { Thread.sleep(sleep / 1_000_000L, (int) (sleep % 1_000_000L)); } catch (InterruptedException ie) { break; } }
                        }
                    }
                }
            });
            ws.add(w); w.start();
        }
        for (Thread w : ws) w.join();
        running.set(false);
        try { Thread.sleep(1200); } catch (InterruptedException e) {}
        csv.flush(); csv.close();
        producer.shutdown();
        System.out.println("PRODUCE_DONE okTotal=" + okTotal.get() + " failTotal=" + failTotal.get() + " runId=" + runId);
    }

    static void verify(String[] a) throws Exception {
        final String namesrv = a[1];
        final String topic = a[2];
        final String runId = a[3];
        final int idleSec = Integer.parseInt(a[4]);
        final Set<String> seen = ConcurrentHashMap.newKeySet();
        final AtomicLong lastMsgAt = new AtomicLong(System.currentTimeMillis());
        final AtomicLong dup = new AtomicLong();

        DefaultMQPushConsumer c = new DefaultMQPushConsumer("verify_" + runId);
        c.setNamesrvAddr(namesrv);
        c.setConsumeFromWhere(ConsumeFromWhere.CONSUME_FROM_FIRST_OFFSET);
        c.setConsumeMessageBatchMaxSize(32);
        c.subscribe(topic, "*");
        c.registerMessageListener(new MessageListenerConcurrently() {
            public ConsumeConcurrentlyStatus consumeMessage(List<MessageExt> msgs, ConsumeConcurrentlyContext ctx) {
                for (MessageExt m : msgs) {
                    String b = new String(m.getBody(), StandardCharsets.UTF_8);
                    if (b.startsWith(runId + ":")) {
                        if (!seen.add(b)) dup.incrementAndGet();
                        lastMsgAt.set(System.currentTimeMillis());
                    }
                }
                return ConsumeConcurrentlyStatus.CONSUME_SUCCESS;
            }
        });
        c.start();
        System.out.println("VERIFY consuming topic=" + topic + " runId=" + runId);
        while (System.currentTimeMillis() - lastMsgAt.get() < idleSec * 1000L) {
            Thread.sleep(500);
        }
        c.shutdown();
        System.out.println("VERIFY_DONE unique=" + seen.size() + " dup=" + dup.get() + " runId=" + runId);
    }

    static void bump(ConcurrentHashMap<String, AtomicLong> m, String k) {
        AtomicLong x = m.get(k);
        if (x == null) { x = new AtomicLong(); AtomicLong p = m.putIfAbsent(k, x); if (p != null) x = p; }
        x.incrementAndGet();
    }

    static long pct(List<Long> sorted, int p) {
        if (sorted.isEmpty()) return 0;
        int idx = (int) Math.ceil(p / 100.0 * sorted.size()) - 1;
        if (idx < 0) idx = 0; if (idx >= sorted.size()) idx = sorted.size() - 1;
        return sorted.get(idx);
    }
}
