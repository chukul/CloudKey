#!/bin/bash
# Monitor console logs for CloudKey updates
log stream --predicate 'process == "CloudKey"' --level debug --style compact &
LOG_PID=$!
sleep 10
kill $LOG_PID
