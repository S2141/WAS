#!/bin/bash

# Stop WAS

LOG_FILE="/root/scripts/was/LOGS/Testing.log"

# Kill processes with name 'server01'
for pid in $(ps -ef | grep server01 | grep -v grep | awk '{print $2}'); do kill -9 $pid; done   -----to change the servername

# Kill processes with name 'localhostNode02'

for pid in $(ps -ef | grep localhostNode02 | grep -v grep | awk '{print $2}'); do kill -9 $pid; done   ----- to change the node name

echo "Stop Testing is completed...."
echo "Stop process for localhostNode02 is done, server01 is stopped now. $(date +%d-%m-%Y-%H-%M-%S)" >> $LOG_FILE
echo "================================================================================================" >> $LOG_FILE
