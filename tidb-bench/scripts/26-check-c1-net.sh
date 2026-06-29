#!/bin/bash
set -e
for ip in 10.142.0.10 10.142.0.11 10.142.0.12 10.142.0.13; do
  if timeout 3 bash -lc "</dev/tcp/${ip}/4000"; then
    echo "${ip}:4000 OK"
  else
    echo "${ip}:4000 FAIL"
  fi
done
