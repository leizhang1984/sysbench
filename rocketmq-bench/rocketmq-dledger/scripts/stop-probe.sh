#!/bin/bash
pkill -9 -f "Probe produce" 2>/dev/null
sleep 1
echo "remaining=$(pgrep -f 'Probe produce' | wc -l)"
