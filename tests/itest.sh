#!/bin/bash

# Function to get the host port for a service
get_host_port() {
  local service=$1
  local port=$2
  port=$(docker-compose port "$service" "$port" | cut -d: -f2)
  echo "$port"
}

# Function to create a Toxiproxy listen/upstream pair
create_toxiproxy_listen_upstream() {
  local proxy_name=$1
  local listen_port=$2
  local upstream_host=$3
  local upstream_port=$4

  docker exec "$TOXIPROXY_CONTAINER_NAME" /toxiproxy-cli create --listen 0.0.0.0:"$listen_port" --upstream "$upstream_host":"$upstream_port" "$proxy_name"
}

# Function to subscribe to a topic in the background and create a temporary file
subscribe_background() {
  local topic=$1
  local mqtt_output_file
  mqtt_output_file=$(mktemp)
  docker exec "$MOSQUITTO_CONTAINER_NAME" mosquitto_sub -h localhost -p 1883 -t "$topic" > "$mqtt_output_file" &
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
  local binary=$1
  local broker_port=$2
  "$binary" -p "$broker_port" >/dev/null 2>&1 &
  echo $!
}

# Function to stop and remove the MQTT broker container
cleanup() {
  # Stop and remove the containers
  docker-compose down
  rm -f "$mqtt_output_file"
}

binary="../$1"

# Start the services
docker-compose up -d

# Set up trap to ensure cleanup on script termination or interruption
trap cleanup EXIT

TOXIPROXY_CONTAINER_NAME=$(docker-compose ps -q toxiproxy)
MOSQUITTO_CONTAINER_NAME=$(docker-compose ps -q mosquitto)

# Create Toxiproxy listen/upstream pair for MQTT broker
create_toxiproxy_listen_upstream mqtt-broker 1884 mosquitto 1883
mosquitto_via_toxiproxy_port=$(get_host_port toxiproxy 1884)

# Subscribe to the topic in the background and get the temporary file
mqtt_output_file=$(subscribe_background "$(hostname)/status")
sleep 3

# Start the binary with the broker port and get its PID
binary_pid=$(start_binary "$binary" "$mosquitto_via_toxiproxy_port")

# Wait for the "online" message
check_message "online" "$mqtt_output_file" 10  # Adjust the timeout as needed

# ADD toxic
docker exec "$TOXIPROXY_CONTAINER_NAME" /toxiproxy-cli toxic add -t timeout -n timeout_downstream -a timeout=1 mqtt-broker
check_message "offline" "$mqtt_output_file" 30  # Adjust the timeout as needed

# REMOVE toxic
docker exec "$TOXIPROXY_CONTAINER_NAME" /toxiproxy-cli toxic remove -n timeout_downstream mqtt-broker
check_message "online" "$mqtt_output_file" 20  # Adjust the timeout as needed

# Kill the binary and wait for the "offline" message
kill "$binary_pid"
check_message "offline" "$mqtt_output_file" 10  # Adjust the timeout as needed

