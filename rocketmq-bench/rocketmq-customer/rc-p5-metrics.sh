#!/bin/bash
awk -F, 'NR>1{f+=$5;if($5>0){c++;if(first=="")first=$2;last=$2}} END{print "fail_sum="f,"fail_rows="c,"first_fail="first,"last_fail="last}' /opt/probe/ft_ftE.csv
tail -1 /opt/probe/ft_ftE.csv
