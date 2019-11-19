#!/bin/bash
echo "This script add all number from file add.txt upto precision of two decimal places"
awk '{ sum += $1 } END { printf "%0.2f\n", sum }' add.txt
