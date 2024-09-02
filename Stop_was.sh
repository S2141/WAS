#!/bin/bash

# Default path
DEFAULT_PATH="/opt/IBM/WebSphere/AppServer"

# Define log file path with date and time
LOG_FILE="/opt/IBM/WebSphere/AppServer/profiles/stop_$(date +'%Y_%m_%d').log"

# Clear the log file
: > "$LOG_FILE"

# Function to stop a WebSphere server
stop_server() {
    local profile_name="$1"
    local server_name="$2"

    local full_path="$DEFAULT_PATH/profiles/$profile_name"
    echo "Stopping server $server_name at path $full_path..." | tee -a "$LOG_FILE"

    "$full_path/bin/stopServer.sh" "$server_name" -username wasadmin -password P@ssw0rd 2>&1 | tee -a "$LOG_FILE"
    if [ $? -eq 0 ]; then
        echo "Server $server_name stopped successfully." | tee -a "$LOG_FILE"
    else
        echo "Failed to stop server $server_name." | tee -a "$LOG_FILE"
    fi
}

# Function to stop a node
stop_node() {
    local profile_name="$1"

    local full_path="$DEFAULT_PATH/profiles/$profile_name"
    echo "Stopping node at path $full_path..." | tee -a "$LOG_FILE"

    "$full_path/bin/stopNode.sh" -username wasadmin -password P@ssw0rd 2>&1 | tee -a "$LOG_FILE"
    if [ $? -eq 0 ]; then
        echo "Node stopped successfully." | tee -a "$LOG_FILE"
    else
        echo "Failed to stop node." | tee -a "$LOG_FILE"
    fi
}

# Get the Java processes that contain WebSphere details
java_processes=$(ps -ef | grep java | grep -v grep)

if [ -z "$java_processes" ]; then
    echo "No running WebSphere Java processes found." | tee -a "$LOG_FILE"
    exit 1
fi

# Collect profiles for servers, excluding nodeagent
declare -A server_profiles

while IFS= read -r java_process; do
    # Debug: print the Java process details
    echo "Found Java process: $java_process" | tee -a "$LOG_FILE"

    # Extract profile name and server name for application servers
    if [[ "$java_process" =~ profiles/([^/]+)/servers/([^/]+) ]]; then
        PROFILE_NAME="${BASH_REMATCH[1]}"
        SERVER_NAME="${BASH_REMATCH[2]}"

        # Check if it's nodeagent and skip if so
        if [[ "$SERVER_NAME" != "nodeagent" ]]; then
            # Add to server profiles
            server_profiles["$PROFILE_NAME"]+="$SERVER_NAME "
        fi
    fi
done <<< "$java_processes"

# Identify the Deployment Manager profile
DMGR_PROFILE_NAME=""
PROFILE_NAMES=($(ls $DEFAULT_PATH/profiles))

for profile_name in "${PROFILE_NAMES[@]}"; do
    if [ -d "$DEFAULT_PATH/profiles/$profile_name/servers/dmgr" ]; then
        DMGR_PROFILE_NAME="$profile_name"
        break
    fi
done

# Stop Application Servers
for profile_name in "${!server_profiles[@]}"; do
    for server_name in ${server_profiles["$profile_name"]}; do
        # Skip stopping the Deployment Manager here if it's already being handled separately
        if [[ "$profile_name" == "$DMGR_PROFILE_NAME" && "$server_name" == "dmgr" ]]; then
            echo "Skipping stopping dmgr as it will be handled separately." | tee -a "$LOG_FILE"
            continue
        fi
        stop_server "$profile_name" "$server_name"
    done
done

# Stop Deployment Manager (dmgr) if found and running
if [ -n "$DMGR_PROFILE_NAME" ]; then
    DMGR_PROFILE_PATH="$DEFAULT_PATH/profiles/$DMGR_PROFILE_NAME"

    # Check if dmgr is running
    dmgr_pid=$(pgrep -f "$DMGR_PROFILE_PATH/servers/dmgr")
    if [ -n "$dmgr_pid" ]; then
        echo "Stopping Deployment Manager in profile $DMGR_PROFILE_PATH..." | tee -a "$LOG_FILE"

        # Stop the Deployment Manager
        "$DMGR_PROFILE_PATH/bin/stopManager.sh" -username wasadmin -password P@ssw0rd 2>&1 | tee -a "$LOG_FILE"

        # Wait for 30 seconds to allow the dmgr process to stop gracefully
        echo "Waiting for 30 seconds to allow dmgr to stop gracefully..." | tee -a "$LOG_FILE"
        sleep 30

        # Verify if dmgr is still running
        if pgrep -f "$DMGR_PROFILE_PATH/servers/dmgr" > /dev/null; then
            echo "Deployment Manager is still running." | tee -a "$LOG_FILE"
        else
            echo "Deployment Manager stopped successfully." | tee -a "$LOG_FILE"
        fi
    else
        echo "Deployment Manager is already stopped." | tee -a "$LOG_FILE"
    fi
else
    echo "Deployment Manager profile not found." | tee -a "$LOG_FILE"
fi

# Stop Nodes after stopping all servers
for profile_name in "${PROFILE_NAMES[@]}"; do
    full_path="$DEFAULT_PATH/profiles/$profile_name"
    if pgrep -f "profiles/$profile_name/servers/nodeagent" > /dev/null; then
        stop_node "$profile_name"
    else
        echo "No nodeagent processes are running in profile $profile_name. Skipping node stop." | tee -a "$LOG_FILE"
    fi
done

sleep 10

# Check if any nodeagent is still running and stop it using stopNode.sh
for profile_name in "${PROFILE_NAMES[@]}"; do
    full_path="$DEFAULT_PATH/profiles/$profile_name"
    if pgrep -f "profiles/$profile_name/servers/nodeagent" > /dev/null; then
        echo "nodeagent is still running in profile $profile_name. Attempting to stop it..." | tee -a "$LOG_FILE"
        "$full_path/bin/stopNode.sh" -username wasadmin -password P@ssw0rd 2>&1 | tee -a "$LOG_FILE"
        if [ $? -eq 0 ]; then
            echo "Nodeagent stopped successfully for profile $profile_name." | tee -a "$LOG_FILE"
        else
            echo "Failed to stop nodeagent for profile $profile_name." | tee -a "$LOG_FILE"
        fi
    else
        echo "No nodeagent processes are running in profile $profile_name." | tee -a "$LOG_FILE"
    fi
done
