#!/bin/bash

# Default path
DEFAULT_PATH="/opt/IBM/WebSphere/AppServer"

# Define log file path with date and time
LOG_FILE="/opt/IBM/WebSphere/AppServer/profiles/start_was_$(date +'%Y_%m_%d').log"

# Clear the log file
: > "$LOG_FILE"

# Function to clear cache and start both node agent and servers given the profile path
start_node_and_servers() {
    local profile_path="$1"
    local profile_name="$2"

    echo "Clearing cache for profile $profile_path..." | tee -a "$LOG_FILE"
    "$profile_path/bin/clearClassCache.sh" 2>&1 | tee -a "$LOG_FILE"
    "$profile_path/bin/osgiCfgInit.sh" 2>&1 | tee -a "$LOG_FILE"

    echo "Starting node agent in profile $profile_path..." | tee -a "$LOG_FILE"
    "$profile_path/bin/startNode.sh" -username devops -password devops@123 2>&1 | tee -a "$LOG_FILE"

    echo "Starting servers in profile $profile_path..." | tee -a "$LOG_FILE"
    SERVER_NAMES=$("$profile_path/bin/serverStatus.sh" -all 2>&1 | awk '/Server name:/ {print $NF}')
    for server_name in $SERVER_NAMES; do
        SERVER_STATUS=$("$profile_path/bin/serverStatus.sh" "$server_name" 2>&1 | grep -oP '(STARTED|STOPPED)')
        if [ "$SERVER_STATUS" == "STARTED" ]; then
            echo "Server $server_name is already running. Skipping..." | tee -a "$LOG_FILE"
        else
            echo "Starting server $server_name..." | tee -a "$LOG_FILE"
            "$profile_path/bin/startServer.sh" "$server_name" -username devops -password devops@123 2>&1 | tee -a "$LOG_FILE"
        fi
    done

    echo "Profile $profile_name has been started successfully." | tee -a "$LOG_FILE"
}

# List profiles
echo "Listing profiles..." | tee -a "$LOG_FILE"
PROFILES=$("$DEFAULT_PATH/bin/manageprofiles.sh" -listProfiles 2>&1)
echo "$PROFILES" | tee -a "$LOG_FILE"

# Extract profile names from the output
readarray -t PROFILE_NAMES <<< "$(echo "$PROFILES" | grep -oP '\b\w+\b')"

echo "Profiles found: ${PROFILE_NAMES[*]}" | tee -a "$LOG_FILE"

# Identify the Deployment Manager profile
DMGR_PROFILE_NAME=""
for profile_name in "${PROFILE_NAMES[@]}"; do
    if [[ "$profile_name" == *"Dmgr"* ]]; then
        DMGR_PROFILE_NAME="$profile_name"
        break
    fi
done

# Start Deployment Manager (dmgr) if found
if [ -n "$DMGR_PROFILE_NAME" ]; then
    DMGR_PROFILE_PATH="$DEFAULT_PATH/profiles/$DMGR_PROFILE_NAME"
    echo "Starting Deployment Manager in profile $DMGR_PROFILE_PATH..." | tee -a "$LOG_FILE"
    "$DMGR_PROFILE_PATH/bin/startManager.sh" -username devops -password devops@123 2>&1 | tee -a "$LOG_FILE"

    # Wait for the Deployment Manager to fully start
    echo "Waiting for the Deployment Manager to fully start..." | tee -a "$LOG_FILE"
    sleep 30

    # Check the status of all servers in the Deployment Manager profile
    echo "Checking the status of all servers in the Deployment Manager profile..." | tee -a "$LOG_FILE"
    "$DMGR_PROFILE_PATH/bin/serverStatus.sh" -all -username devops -password devops@123 2>&1 | tee -a "$LOG_FILE"

    echo "Profile $DMGR_PROFILE_NAME (Deployment Manager) has been started successfully." | tee -a "$LOG_FILE"
else
    echo "Deployment Manager profile not found. Skipping Deployment Manager process." | tee -a "$LOG_FILE"
fi

# Iterate over each profile (excluding the Deployment Manager profile if it exists)
for profile_name in "${PROFILE_NAMES[@]}"; do
    if [ "$profile_name" == "$DMGR_PROFILE_NAME" ]; then
        continue
    fi

    echo "Found profile: $profile_name" | tee -a "$LOG_FILE"

    # Construct the full path to the profile's bin directory
    PROFILE_PATH="$DEFAULT_PATH/profiles/$profile_name"

    # Call the function to clear cache and start node agent and servers simultaneously
    start_node_and_servers "$PROFILE_PATH" "$profile_name"
done

echo "All mentioned profiles have been started successfully." | tee -a "$LOG_FILE"
