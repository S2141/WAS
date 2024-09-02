#!/bin/bash

# Variables
HTTPD_BIN_PATH="/opt/IBM/HTTPServer/bin"
HTTPD_STOP_SCRIPT="apachectl -k stop"

# Function to check if httpd is running
check_httpd() {
    ps -ef | grep -v grep | grep httpd
}

# Stop the HTTP Server
stop_httpd() {
    echo "Stopping IBM HTTP Server..."
    $HTTPD_BIN_PATH/$HTTPD_STOP_SCRIPT
}

# Main script logic
if check_httpd > /dev/null
then
    stop_httpd
    sleep 5  # Give it some time to stop
    if check_httpd > /dev/null
    then
        echo "Failed to stop IBM HTTP Server."
    else
        echo "IBM HTTP Server stopped successfully."
    fi
else
    echo "IBM HTTP Server is not running."
fi

# Display the running httpd processes
echo "Checking running httpd processes..."
ps -ef | grep httpd
