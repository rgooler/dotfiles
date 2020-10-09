#!/bin/bash

OLD_IP=0.0.0.0
if [ -f "/etc/ipaddrmonitor" ]; then
    OLD_IP=$(cat /etc/ipaddrmonitor)
fi

NEW_IP=$(curl -q ifconfig.me 2>/dev/null)
if [ "$OLD_IP" != "$NEW_IP" ]; then
    echo "$NEW_IP" >> /etc/ipaddrmonitor
    exit 1
else
    exit 0
fi
