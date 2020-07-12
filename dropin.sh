#!/bin/bash

SO_OPTIONS="keepalive,keepidle=30,keepintvl=30,keepcnt=2"
SOURCE="127.0.0.1:30978"
AVR_IN_PORT="37981"
CONVERT_OPTIONS=""
while sleep 5
do
	socat -d -u "TCP:$SOURCE,$SO_OPTIONS" STDOUT | /usr/local/share/uat2esnt $CONVERT_OPTIONS \
        | socat -d -u STDIN "TCP:localhost:$AVR_IN_PORT,$SO_OPTIONS"
done
