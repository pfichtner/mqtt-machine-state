#!/bin/bash

BINARY_PATH="../$1"

# Function to generate a random free port
get_random_free_port() {
    local port
    while true; do
        port=$((RANDOM % (49151 - 1024) + 1024))
        (echo > /dev/tcp/localhost/$port) >/dev/null 2>&1 || break
    done
    echo $port
}

# Function to start the MQTT broker container with a random free port on the host
start_mqtt_broker() {
    local random_port=$(get_random_free_port)
    docker run --rm -d --name mqtt-broker -p $random_port:1883 -v $PWD/mosquitto/config/mosquitto.conf:/mosquitto/config/mosquitto.conf eclipse-mosquitto >/dev/null
    echo $random_port
}

# Function to start the binary with the given broker port and return its PID
start_binary() {
    local broker_port=$1
    "$BINARY_PATH" -p $broker_port >/dev/null 2>&1 &
    echo $!
}

# Function to wait for the MQTT broker to be ready
wait_for_broker() {
    until docker exec mqtt-broker mosquitto_pub -h localhost -p 1883 -t 'test' -m "test" &> /dev/null; do
        sleep 1
    done
}

# Function to subscribe to a topic in the background and create a temporary file
subscribe_background() {
    local topic=$1
    local mqtt_output_file
    mqtt_output_file=$(mktemp)
    docker exec mqtt-broker mosquitto_sub -h localhost -p 1883 -t $topic > "$mqtt_output_file" &
    echo "$mqtt_output_file"
}

# Function to check if a message is published on a topic
check_message() {
    local expected_message=$1
    local mqtt_output_file=$2
    local timeout=$3
    
    # Wait for the specified timeout to check if the message is received
    timeout $timeout tail -F "$mqtt_output_file" | grep -q "$expected_message" && echo "SUCCESS: Received message: $expected_message" || (echo "FAILURE: Expected $expected_message, but received none" && exit 1)
}

clear_message() {
    local mqtt_output_file=$1
    echo '' >"$mqtt_output_file"
}

# Function to stop and remove the MQTT broker container
cleanup() {
    docker rm -f mqtt-broker >/dev/null
}

# Set up trap to ensure cleanup on script termination or interruption
trap cleanup EXIT

# Start the MQTT broker container with a random free port on the host
mqtt_broker_port=$(start_mqtt_broker)

# Wait for the MQTT broker to be ready
wait_for_broker

# Subscribe to the topic in the background and get the temporary file
mqtt_output_file=$(subscribe_background "$(hostname)/status")
sleep 3

# Start the binary with the broker port and get its PID
binary_pid=$(start_binary $mqtt_broker_port)

# Wait for the "online" message
check_message "online" "$mqtt_output_file" 10  # Adjust the timeout as needed
clear_message "$mqtt_output_file"

# Kill the binary and wait for the "offline" message
kill $binary_pid
check_message "offline" "$mqtt_output_file" 10  # Adjust the timeout as needed
clear_message "$mqtt_output_file"

