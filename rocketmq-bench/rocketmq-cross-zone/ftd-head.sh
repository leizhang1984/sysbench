#!/bin/bash
awk -F, 'NR>1 && ($5+0)>0 {print $3" | "$2" | ok="$4" | fail="$5" | ftot="$7" | "$11}' /opt/probe/ft_ftD.csv | head -28
