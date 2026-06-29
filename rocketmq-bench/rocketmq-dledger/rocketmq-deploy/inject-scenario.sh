#!/bin/bash
# Self-timed fault injection at an ABSOLUTE wall-clock target, so multiple hosts fire together.
# Runs as a systemd transient unit (survives run-command SIGTERM).
# Schedule:  inject-scenario.sh <kill9|stop> <AT_EPOCH_SEC> <HOLD_SEC>
# Worker:    inject-scenario.sh _worker   (reads MODE/AT/HOLD from env)
LOG=/var/log/inject-scenario.log
if [ "$1" != "_worker" ]; then
  MODE="${1:-kill9}"
  AT="${2:-0}"
  HOLD="${3:-30}"
fi

run_unit() {
  systemctl reset-failed inject-scenario.service 2>/dev/null
  systemd-run --unit=inject-scenario --setenv=MODE="$MODE" --setenv=AT="$AT" --setenv=HOLD="$HOLD" /bin/bash /opt/inject-scenario.sh _worker
}

worker() {
  ts() { date +%s%3N; }
  hr() { date '+%H:%M:%S.%3N'; }
  echo "=== scenario mode=$MODE at=$AT hold=$HOLD host=$(hostname) now=$(ts) ===" >> $LOG
  NOW=$(date +%s)
  WAIT=$(( AT - NOW ))
  if [ "$WAIT" -gt 0 ]; then sleep "$WAIT"; fi
  PID=$(pgrep -f 'org.apache.rocketmq.broker.BrokerStartup' | head -n1)
  echo "$(ts) $(hr) BEFORE_INJECT pid=$PID mode=$MODE" >> $LOG
  if [ "$MODE" = "kill9" ]; then
    kill -9 "$PID"
    echo "$(ts) $(hr) SENT_KILL9 pid=$PID" >> $LOG
    sleep "$HOLD"
    echo "$(ts) $(hr) RECOVER_START systemctl start" >> $LOG
    systemctl start rocketmq-broker
    for i in $(seq 1 60); do
      if ss -ltn 2>/dev/null | grep -q ':40911'; then echo "$(ts) $(hr) PORT40911_UP after ${i}s" >> $LOG; break; fi
      sleep 1
    done
  elif [ "$MODE" = "stop" ]; then
    kill -STOP "$PID"
    echo "$(ts) $(hr) SENT_SIGSTOP pid=$PID (process frozen, no RST)" >> $LOG
    sleep "$HOLD"
    echo "$(ts) $(hr) RECOVER_CONT kill -CONT" >> $LOG
    kill -CONT "$PID"
    echo "$(ts) $(hr) SENT_CONT pid=$PID" >> $LOG
  fi
  NEWPID=$(pgrep -f 'org.apache.rocketmq.broker.BrokerStartup' | head -n1)
  echo "$(ts) $(hr) DONE newpid=$NEWPID active=$(systemctl is-active rocketmq-broker)" >> $LOG
}

case "$1" in
  _worker) worker ;;
  *) run_unit; echo "scenario scheduled mode=$MODE at=$AT hold=$HOLD now_epoch=$(date +%s); log=$LOG" ;;
esac
