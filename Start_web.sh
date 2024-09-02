#!/bin/bash

# Variables
HTTPD_BIN_PATH="/opt/IBM/HTTPServer/bin"
HTTPD_START_SCRIPT="apachectl -k start"

# Function to check if httpd is running
check_httpd() {
    ps -ef | grep -v grep | grep httpd
}

# Start the HTTP Server
start_httpd() {
    echo "Starting IBM HTTP Server..."
    $HTTPD_BIN_PATH/$HTTPD_START_SCRIPT
}

# Main script logic
if check_httpd > /dev/null
then
    echo "IBM HTTP Server is already running."
else
    start_httpd
    sleep 5  # Give it some time to start
    if check_httpd > /dev/null
    then
        echo "IBM HTTP Server started successfully."
    else
        echo "Failed to start IBM HTTP Server."
    fi
fi

# Display the running httpd processes
echo "Checking running httpd processes..."
ps -ef | grep httpd
