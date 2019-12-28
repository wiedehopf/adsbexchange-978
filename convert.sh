#!/bin/sh

trap "exit" INT TERM
trap "kill 0" EXIT

while sleep 1
do
	sleep 5 &
	socat -u "TCP:$SOURCE,keepalive,keepidle=30,keepintvl=30,keepcnt=2,connect-timeout=10,forever,interval=15" STDOUT | "$IPATH/uat2esnt" $CONVERT_OPTIONS | socat -u STDIN "TCP:localhost:$AVR_IN_PORT"
	wait
done &


wait
