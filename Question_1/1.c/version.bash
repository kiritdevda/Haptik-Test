#/bin/bash
awk -F: '$1=="\"version\""{gsub(/"/, "", $2);printf "%0.2f\n", $2;exit;}' version.txt
