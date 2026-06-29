#!/bin/bash
# Launch detached probe PRODUCE on client01.
# Args (via az --parameters): RUNID DURSEC THREADS RATE RETRIES
RUNID="${1:?need RUNID}"
DURSEC="${2:-180}"
THREADS="${3:-8}"
RATE="${4:-50}"
RETRIES="${5:-2}"
CSV="/opt/probe/ft_${RUNID}.csv"
mkdir -p /opt/probe
export JAVA_HOME=$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")
export PATH=$JAVA_HOME/bin:$PATH
ROCKETMQ_HOME=/opt/rocketmq-4.9.7
NS="10.163.0.4:9876;10.163.0.5:9876;10.163.0.6:9876"
LOG="/opt/probe/produce_${RUNID}.log"
rm -f "/opt/probe/DONE_${RUNID}"
setsid bash -c "
  java -cp '$ROCKETMQ_HOME/lib/*:/opt/probe' Probe produce \
    '$NS' ft_topic $THREADS $DURSEC $RATE '$CSV' '$RUNID' $RETRIES > '$LOG' 2>&1
  touch /opt/probe/DONE_${RUNID}
" >/dev/null 2>&1 < /dev/null &
echo "produce launched runId=$RUNID dur=${DURSEC}s threads=$THREADS rate=$RATE retries=$RETRIES csv=$CSV"
