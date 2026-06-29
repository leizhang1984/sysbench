#!/usr/bin/env python3
# Failover availability probe for ES 6.8.1 dsv6 cluster.
# - Round-robins write requests across all 3 nodes at ~10 Hz (client-pool simulation).
# - Short per-request timeout so a SIGSTOP-frozen node (no RST) hangs until timeout then fails,
#   capturing the real client interruption window.
# - Every 1s samples cluster health + current master from any reachable node.
# Outputs two CSVs: requests log + state log.
import json
import sys
import time
import urllib.request
import urllib.error
from datetime import datetime, timezone

NODES = ["10.122.0.7", "10.122.0.8", "10.122.0.9"]
PORT = 9200
INDEX = "failover-test"
REQ_TIMEOUT = 2.0          # seconds per request
HEALTH_TIMEOUT = 2.0
HZ = 10.0                  # write attempts per second
DUR = float(sys.argv[1]) if len(sys.argv) > 1 else 60.0
TAG = sys.argv[2] if len(sys.argv) > 2 else "run"

REQ_CSV = "/tmp/fo_requests_%s.csv" % TAG
STATE_CSV = "/tmp/fo_state_%s.csv" % TAG


def now_ms():
    return time.time()


def iso(ts):
    return datetime.fromtimestamp(ts, tz=timezone.utc).strftime("%H:%M:%S.%f")[:-3]


def http(method, url, body=None, timeout=REQ_TIMEOUT):
    data = body.encode() if body else None
    req = urllib.request.Request(url, data=data, method=method)
    if body:
        req.add_header("Content-Type", "application/json")
    t0 = time.time()
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            payload = r.read()
            return True, (time.time() - t0) * 1000.0, r.status, payload
    except urllib.error.HTTPError as e:
        return False, (time.time() - t0) * 1000.0, e.code, b""
    except Exception as e:
        return False, (time.time() - t0) * 1000.0, -1, str(e).encode()


def sample_state(reqf, statef):
    # try each node until one answers
    for ip in NODES:
        ok, lat, code, payload = http(
            "GET", "http://%s:%d/_cluster/health/%s" % (ip, PORT, INDEX),
            timeout=HEALTH_TIMEOUT)
        if ok:
            try:
                h = json.loads(payload)
            except Exception:
                continue
            ok2, _, _, mpayload = http(
                "GET", "http://%s:%d/_cat/master?h=node" % (ip, PORT),
                timeout=HEALTH_TIMEOUT)
            master = mpayload.decode().strip() if ok2 else "?"
            ts = now_ms()
            statef.write("%s,%.3f,%s,%s,%d,%d,%d,%d,%s\n" % (
                iso(ts), ts, h.get("status", "?"), master,
                h.get("active_shards", -1), h.get("unassigned_shards", -1),
                h.get("relocating_shards", -1), h.get("initializing_shards", -1),
                ip))
            statef.flush()
            return
    # no node answered
    ts = now_ms()
    statef.write("%s,%.3f,UNREACHABLE,?,-1,-1,-1,-1,none\n" % (iso(ts), ts))
    statef.flush()


def main():
    seq = 0
    reqf = open(REQ_CSV, "w")
    statef = open(STATE_CSV, "w")
    reqf.write("ts_iso,ts_epoch,target,ok,latency_ms,http_code,detail\n")
    statef.write("ts_iso,ts_epoch,status,master,active_shards,unassigned,relocating,initializing,via\n")

    start = time.time()
    next_write = start
    next_state = start
    interval = 1.0 / HZ
    while time.time() - start < DUR:
        loop = time.time()
        if loop >= next_state:
            sample_state(reqf, statef)
            next_state += 1.0
        if loop >= next_write:
            target = NODES[seq % len(NODES)]
            body = json.dumps({"seq": seq, "tag": TAG, "t": loop})
            ok, lat, code, payload = http(
                "PUT", "http://%s:%d/%s/_doc/%s_%d" % (target, PORT, INDEX, TAG, seq),
                body)
            detail = "" if ok else payload.decode(errors="replace")[:60].replace(",", ";").replace("\n", " ")
            ts = now_ms()
            reqf.write("%s,%.3f,%s,%d,%.1f,%d,%s\n" % (
                iso(ts), ts, target, 1 if ok else 0, lat, code, detail))
            reqf.flush()
            seq += 1
            next_write += interval
        sleep = min(next_write, next_state) - time.time()
        if sleep > 0:
            time.sleep(min(sleep, interval))
    reqf.close()
    statef.close()
    print("DONE tag=%s requests=%s state=%s seq=%d" % (TAG, REQ_CSV, STATE_CSV, seq))


if __name__ == "__main__":
    main()
