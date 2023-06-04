#!/bin/bash

############################# SETTINGS #############################

# Relative or absolute path of minecraft server jar
# Recommened to use paper, https://papermc.io/
# This file will be parsed by the shell (and potentially globbed), to prevent this set your needed value in two double quotes ( "\"No*globbing_here.jar\"" )
readonly server_jar="AUTOUPDATE_server.jar_*.jar"

# Memory to leave for the operating system
# Calculated using:
# Total system memory - this value = Value used for jvm
# This value has to be in mebibytes, without units
# https://www.gbmb.org/gb-to-mb
readonly leave_memory=1536 # 1.5GB

# A relative or absolute path to a file containing the server version only
# This file should contain 1 line, which is the server version, as shown in the mc launcher (eg. 1.19.4)
# Snapshots are not supported
readonly mc_version_file="target.mcversion"

# If to restart on crash
readonly restart=true

# Time to wait until to restart
# Recommened to be 5+ seconds to allow the jvm to stop
# Please provide in seconds without units
readonly restart_delay=5

# Restart flag, used to know that the server requested a restart
# Must be the same as in restart.sh
# On spigot (based) servers set the restart script to ./restart.sh in spigot.yml
readonly restart_flag=".restart"

# Flags to pass to jvm
# -Xms, -Xmx -jar are set separately
readonly jvm_flags=(
    "-XX:+UseG1GC"
    "-XX:+ParallelRefProcEnabled"
    "-XX:MaxGCPauseMillis=200"
    "-XX:+UnlockExperimentalVMOptions"
    "-XX:+DisableExplicitGC"
    "-XX:+AlwaysPreTouch"
    "-XX:G1NewSizePercent=30"
    "-XX:G1MaxNewSizePercent=40"
    "-XX:G1HeapRegionSize=8M"
    "-XX:G1ReservePercent=20"
    "-XX:G1HeapWastePercent=5"
    "-XX:G1MixedGCCountTarget=4"
    "-XX:InitiatingHeapOccupancyPercent=15"
    "-XX:G1MixedGCLiveThresholdPercent=90"
    "-XX:G1RSetUpdatingPauseTimePercent=5"
    "-XX:SurvivorRatio=32"
    "-XX:+PerfDisableSharedMem"
    "-XX:MaxTenuringThreshold=1"
    "-Dusing.aikars.flags=https://mcflags.emc.gs"
    "-Daikars.new.flags=true"
)

# Flags to pass to minecraft
# Usually there is not much to set here
readonly mc_flags=(
    "--nogui"
)

############################# END OF SETTINGS #############################


# Check that all required file exist
# shellcheck disable=SC2086
if [ ! -f $server_jar ]; then
    printf "Error: server jar (%s) not found\n" "$server_jar" >&2
    exit 1
fi
# shellcheck disable=SC2086
if [ ! -f $mc_version_file ]; then
    printf "Error: minecraft version file (%s) not found\n" "$mc_version_file" >&2
    exit 1
fi


# Get required information for the jvm
read -r mc_version < $mc_version_file
if [ -z "$mc_version" ]; then
    printf "Error: first line of server version file (%s) is empty\n" "$mc_version_file" >&2
    exit 1
fi
if [[ "$mc_version" =~ ^(\d+\.\d+|\d+\.\d+\.\d+)$ ]]; then
    printf "Error: server version file (%s) does not contain a valid version\n" "$mc_version_file" >&2
fi

if [[ $(printf "1.17\n%s" "$mc_version" | sort -V | head -1) == 1.17 ]]; then
    # 1.17+
    java_version="17"
else
    # 1.16-
    java_version="8"
fi
java_path=$(update-alternatives --list java | grep "java-$java_version" | head -1)
if [ -z "$java_path" ]; then
    printf "Error: minecraft %s needs java %s. Which is not installed\n" "$mc_version" "$java_version" >&2
    exit 1
fi

free_memory=$(free -m | awk '/^Mem:/ { print $2 }')
jvm_memory=$(("$free_memory" - "$leave_memory"))

java_cmd="$java_path ${jvm_flags[*]} -Xms${jvm_memory}M -Xmx${jvm_memory}M -jar $server_jar ${mc_flags[*]}"


# Start the server
restart () {
    if [ "$restart" = true ]; then
        printf "Restarting in %s seconds... Press Ctrl+C to abort\n" "$restart_delay"
        sleep "$restart_delay"
        printf "\n"
        return 0
    else
        return 2
    fi
}

rm -f "$restart_flag"
printf "\n"
while true; do
    printf "Starting server...\n"
    $java_cmd
    result_code="$?"
    
    if [ "$result_code" -ne 0 ]; then
        printf "Detected non-zero exit code (%s)\n" "$result_code"
        restart || break
    elif [ -f "$restart_flag"  ]; then
        printf "Server has requested restart\n"
        if ! rm "$restart_flag"; then
            # Permissions?
            printf "Error: failed to remove restart flag\n" >&2
            exit 1 # Avoid infinite restart loop
        fi
        restart || break
    else
        printf "Server shutdown\n"
        break
    fi
done
