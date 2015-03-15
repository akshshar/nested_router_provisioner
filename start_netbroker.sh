#!/bin/bash

nohup netbroker -S 2>&1 > /dev/null &
ps -ef | grep netbroker

