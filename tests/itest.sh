#!/bin/bash

BINARY_PATH="../$1"

# Function to get the host port for a service
get_host_port() {
  SERVICE=$1
  PORT=$2
  PORT=$(docker-compose port $SERVICE $PORT | cut -d: -f2)
  echo $PORT
}

# Function to create a Toxiproxy listen/upstream pair
create_toxiproxy_listen_upstream() {
  PROXY_NAME=$1
  LISTEN_PORT=$2
  UPSTREAM_HOST=$3
  UPSTREAM_PORT=$4

  docker exec $TOXIPROXY_CONTAINER_NAME /toxiproxy-cli create --listen 0.0.0.0:$LISTEN_PORT --upstream $UPSTREAM_HOST:$UPSTREAM_PORT $PROXY_NAME 
}

# Function to subscribe to a topic in the background and create a temporary file
subscribe_background() {
    local topic=$1
    local mqtt_output_file
    mqtt_output_file=$(mktemp)
    docker exec $MOSQUITTO_CONTAINER_NAME mosquitto_sub -h localhost -p 1883 -t $topic > "$mqtt_output_file" &
    echo "$mqtt_output_file"
}

# Function to check if a message is published on a topic
check_message() {
    local expected_message=$1
    local mqtt_output_file=$2
    local timeout=$3
    
    # Wait for the specified timeout to check if the message is received
    if timeout "$timeout" tail -F "$mqtt_output_file" | grep -q "$expected_message"; then
        echo "SUCCESS: Received message: $expected_message"
        # Clear the output file
        echo '' > "$mqtt_output_file"
    else
        echo "FAILURE: Expected $expected_message, but received none" && exit 1
    fi
}

# Function to start the binary with the given broker port and return its PID
start_binary() {
    local broker_port=$1
    "$BINARY_PATH" -p $broker_port >/dev/null 2>&1 &
    echo $!
}

# Function to stop and remove the MQTT broker container
cleanup() {
  # Stop and remove the containers
  docker-compose down
  rm $mqtt_output_file
}

# Start the services
docker-compose up -d

TOXIPROXY_CONTAINER_NAME=$(docker-compose ps -q toxiproxy)
MOSQUITTO_CONTAINER_NAME=$(docker-compose ps -q mosquitto)

# Set up trap to ensure cleanup on script termination or interruption
trap cleanup EXIT

# Create Toxiproxy listen/upstream pair for MQTT broker
create_toxiproxy_listen_upstream mqtt-broker 1884 mosquitto 1883


MOSQUITTO_DIRECT_PORT=$(get_host_port mosquitto 1883)
MOSQUITTO_VIA_TOXIPROXY_PORT=$(get_host_port toxiproxy 1884)


# Subscribe to the topic in the background and get the temporary file
mqtt_output_file=$(subscribe_background "$(hostname)/status")
sleep 3

# Start the binary with the broker port and get its PID
binary_pid=$(start_binary $MOSQUITTO_VIA_TOXIPROXY_PORT)

# Wait for the "online" message
check_message "online" "$mqtt_output_file" 10  # Adjust the timeout as needed

# ADD toxic
docker exec $TOXIPROXY_CONTAINER_NAME /toxiproxy-cli toxic add -t timeout -n timeout_downstream -a timeout=1 mqtt-broker
check_message "offline" "$mqtt_output_file" 30  # Adjust the timeout as needed

# REMOVE toxic
docker exec $TOXIPROXY_CONTAINER_NAME /toxiproxy-cli toxic remove -n timeout_downstream mqtt-broker
check_message "online" "$mqtt_output_file" 20  # Adjust the timeout as needed

# Kill the binary and wait for the "offline" message
kill $binary_pid
check_message "offline" "$mqtt_output_file" 10  # Adjust the timeout as needed


