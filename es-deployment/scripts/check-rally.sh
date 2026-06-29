#!/bin/bash
echo "=== host: $(hostname) ==="
echo "--- python3 ---"
python3 --version 2>&1
echo "--- pip3 ---"
pip3 --version 2>&1
echo "--- esrally (which) ---"
which esrally 2>&1
echo "--- esrally version ---"
esrally --version 2>&1 || /usr/local/bin/esrally --version 2>&1 || ~/.local/bin/esrally --version 2>&1
echo "--- pip show esrally ---"
pip3 show esrally 2>&1 | head -n 5
echo "=== done $(hostname) ==="
