#!/bin/bash
#$1 - command to look for

output=$(pidof -x "$1")
if [ -z $output ]; then
	echo false
else
	echo true
fi
