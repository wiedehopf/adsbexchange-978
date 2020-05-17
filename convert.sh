#!/bin/bash

SO_OPTIONS="keepalive,keepidle=30,keepintvl=30,keepcnt=2"
while sleep 5
do
	socat -d -u "TCP:$SOURCE,$SO_OPTIONS" STDOUT | "$IPATH/uat2esnt" $CONVERT_OPTIONS \
        | socat -d -u STDIN "TCP:localhost:$AVR_IN_PORT,$SO_OPTIONS"
done
