#!/bin/bash
cd "$(dirname "$0")"
for f in *.sh; do sed -i 's/\r$//' "$f"; done
chmod +x *.sh
echo "---- syntax check ----"
for f in 00-vars.sh deploy-infra.sh namesrv-setup.sh broker-setup.sh provision-all.sh verify.sh; do
  if bash -n "$f"; then echo "OK $f"; else echo "FAIL $f"; fi
done
