#!/bin/bash

# RUNNING THIS SCRIPT MANUALLY WILL JUST CREATE A FILE
# unless the server is running, where it would restart the server on next stop

############################# SETTINGS #############################

# Restart flag, used to know that the server requested a restart
# Must be the same as in start.sh
# On spigot (based) servers set the restart script to ./restart.sh in spigot.yml
readonly restart_flag=".restart"

############################# END OF SETTINGS #############################

touch "$restart_flag"