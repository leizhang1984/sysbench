#!/bin/bash
for NS in 10.170.0.4 10.170.0.6 10.170.0.5; do
  if timeout 5 bash -c "cat < /dev/null > /dev/tcp/${NS}/9876" 2>/dev/null; then
    echo "${NS}:9876 OPEN"
  else
    echo "${NS}:9876 CLOSED/UNREACHABLE"
  fi
done
