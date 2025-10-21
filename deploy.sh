#!/bin/bash

MYSERVER=transip
rsync -av . $MYSERVER:work/

# Run remote command to restart container if needed
ssh $MYSERVER "cd ~/work && podman compose up -d"