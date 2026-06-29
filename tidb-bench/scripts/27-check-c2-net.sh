#!/bin/bash
set -e
for ip in 10.142.0.30 10.142.0.31 10.142.0.32 10.142.0.33; do
  if timeout 3 bash -lc "</dev/tcp/${ip}/4000"; then
    echo "${ip}:4000 OK"
  else
    echo "${ip}:4000 FAIL"
  fi
done
