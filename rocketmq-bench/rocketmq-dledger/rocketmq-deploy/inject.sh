#!/bin/bash
# Failure injection on a broker VM. Arg1: action = kill9 | stop | cont | start | status
ACT="${1:-status}"
PID=$(pgrep -f 'org.apache.rocketmq.broker.BrokerStartup' | head -1)
TS="$(date +%s%3N) $(date +%H:%M:%S.%3N)"
case "$ACT" in
  kill9)
    echo "$TS KILL9 pid=$PID"
    [ -n "$PID" ] && kill -9 "$PID"
    ;;
  stop)
    echo "$TS SIGSTOP pid=$PID"
    [ -n "$PID" ] && kill -STOP "$PID"
    ;;
  cont)
    echo "$TS SIGCONT pid=$PID"
    [ -n "$PID" ] && kill -CONT "$PID"
    ;;
  start)
    # restart via systemd (for kill9 recovery)
    echo "$TS SYSTEMCTL_START"
    systemctl start rocketmq-broker
    for i in $(seq 1 40); do sleep 2; ss -ltn | grep -q ':40911' && break; done
    echo "svc:$(systemctl is-active rocketmq-broker) p40911:$(ss -ltn | grep -q ':40911' && echo UP || echo DOWN)"
    ;;
  status)
    echo "$TS pid=$PID active=$(systemctl is-active rocketmq-broker) p40911:$(ss -ltn | grep -q ':40911' && echo UP || echo DOWN) state=$(ps -o stat= -p "$PID" 2>/dev/null)"
    ;;
esac
