#!/bin/bash

echo "--- Checking for Plex Updates ---"
sudo apt update

# Only upgrades plexmediaserver if an update is available
sudo apt install --only-upgrade plexmediaserver -y

echo "--- Restarting Plex Service ---"
sudo systemctl restart plexmediaserver

echo "--- Verifying Status ---"
sudo systemctl status plexmediaserver --no-pager