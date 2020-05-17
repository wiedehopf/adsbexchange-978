#!/bin/sh

SO_OPTIONS="keepalive,keepidle=30,keepintvl=30,keepcnt=2,connect-timeout=10,forever,interval=15"
while sleep 1
do
	sleep 5 &
	socat -d -d -u "TCP:$SOURCE,$SO_OPTIONS" STDOUT | "$IPATH/uat2esnt" $CONVERT_OPTIONS \
        | socat -d -d -u STDIN "TCP:localhost:$AVR_IN_PORT,$SO_OPTIONS"
	wait
done
