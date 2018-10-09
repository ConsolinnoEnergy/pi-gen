#!/bin/bash
upSeconds="$(cat /proc/uptime | grep -o '^[0-9]\+')"
upMins=$((${upSeconds} / 60))

if [ "${upMins}" -gt "5" ]
then
	current=`date +%s`
	last_modified=`stat -c "%Y" /tmp/data.txt`
	if [ $(($current-$last_modified)) -gt 180 ]; then
		 exit 1;
	else
		exit 0;
	fi
else
        exit 0;
fi
