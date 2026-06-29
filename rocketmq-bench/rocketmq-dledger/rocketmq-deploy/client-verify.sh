#!/bin/bash
. /etc/profile.d/rocketmq.sh
echo "NAMESRV=$NAMESRV_ADDR"
echo "ROCKETMQ_HOME=$ROCKETMQ_HOME"
echo "--- clusterList ---"
mqadmin clusterList -n "$NAMESRV_ADDR"
