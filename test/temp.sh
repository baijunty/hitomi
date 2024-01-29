#!/usr/bin/env bash
grep --color=never 'cpu MHz' /proc/cpuinfo
value="$(cat /sys/class/thermal/thermal_zone0/temp)"
cpu_temp="((echo "$value")|awk `{print("%0.1f\n",$1/1000.0)}`)"
echo "cpu temperature : ${cpu_temp}"