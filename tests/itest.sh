#!/bin/bash

# Global variable for MQTT output file
MQTT_OUTPUT_FILE=""

# Function to get the host port for a service
get_host_port() {
  local service=$1
  local port=$2
  port=$(docker-compose port "$service" "$port" | cut -d: -f2)
  echo "$port"
}

# Function to create a Toxiproxy listen/upstream pair
create_toxiproxy_listen_upstream() {
  local container_name=$1
  local proxy_name=$2
  local listen_port=$3
  local upstream_host=$4
  local upstream_port=$5

  docker exec "$container_name" /toxiproxy-cli create --listen 0.0.0.0:"$listen_port" --upstream "$upstream_host":"$upstream_port" "$proxy_name"
}

# Function to subscribe to all topics, write messages to a temporary file, and perform a test publish
subscribe_background() {
  local container_name=$1
  MQTT_OUTPUT_FILE=$(mktemp)

  # Start a loop to publish a test message and check for its reception
  local test_topic="test"
  local test_payload="test"

  docker exec "$container_name" mosquitto_sub -h localhost -p 1883 -t '#' -F '%t %p' > "$MQTT_OUTPUT_FILE" &
  while true; do
    docker exec "$container_name" mosquitto_pub -h localhost -p 1883 -t "$test_topic" -m "$test_payload"
    check_message "$test_topic" "$test_payload" 1 && break
  done
}

# Function to check if a message with a specific topic and payload is received
check_message() {
  local expected_topic=$1
  local expected_payload=$2
  local timeout=$3

  # Wait for the specified timeout to check if the message is received
  timeout "$timeout" tail -F "$MQTT_OUTPUT_FILE" | grep -q "$expected_topic $expected_payload" && echo '' > "$MQTT_OUTPUT_FILE"
}

# Function to assert a message and provide details on failure
assert_message() {
  local expected_topic=$1
  local expected_payload=$2
  local timeout=$3

  if check_message "$expected_topic" "$expected_payload" "$timeout"; then
    echo "SUCCESS: Received message on topic '$expected_topic' with payload '$expected_payload'"
  else
    echo "FAILURE: Expected message on topic '$expected_topic' with payload '$expected_payload'"
    echo "Contents of $MQTT_OUTPUT_FILE:"
    cat "$MQTT_OUTPUT_FILE"  
    exit 1
  fi
}

# Function to stop and remove the MQTT broker container
cleanup() {
  # Stop and remove the containers
  docker-compose down
  rm -f "$MQTT_OUTPUT_FILE"
}

# Function to run the tests
run_tests() {
  local binary="../$1"

  # Start the services
  docker-compose up -d
  
  # Set up trap to ensure cleanup on script termination or interruption
  trap cleanup EXIT
  
  local toxiproxy_container_name=$(docker-compose ps -q toxiproxy)
  local mosquitto_container_name=$(docker-compose ps -q mosquitto)
  
  # Create Toxiproxy listen/upstream pair for MQTT broker
  create_toxiproxy_listen_upstream $toxiproxy_container_name mqtt-broker 1884 mosquitto 1883
  local mosquitto_via_toxiproxy_port=$(get_host_port toxiproxy 1884)
  
  # Subscribe to all topics in the background
  subscribe_background $mosquitto_container_name
  
  # Start the binary with the broker port and get its PID
  "$binary" -p "$mosquitto_via_toxiproxy_port" >/dev/null 2>&1 &
  local binary_pid=$!
  
  # Wait for the "online" message
  assert_message "$(hostname)/status" "online" 10
  
  # ADD toxic
  docker exec "$toxiproxy_container_name" /toxiproxy-cli toxic add -t timeout -n timeout_downstream -a timeout=1 mqtt-broker
  assert_message "$(hostname)/status" "offline" 30
  
  # REMOVE toxic
  docker exec "$toxiproxy_container_name" /toxiproxy-cli toxic remove -n timeout_downstream mqtt-broker
  assert_message "$(hostname)/status" "online" 20
  
  # Kill the binary and wait for the "offline" message
  echo "Stopping (killing) $binary with PID $binary_pid"
  kill "$binary_pid" >/dev/null 2>&1
  assert_message "$(hostname)/status" "offline" 10
} 

binary="../$1"
run_tests "$1"

