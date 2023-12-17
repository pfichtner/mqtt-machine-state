#!/bin/bash

# Set the path to the binary
BINARY_PATH="../binaries/mqttmachinestate-linux-amd64"

# Set the path to the approved output file
APPROVED_OUTPUT_FILE="approved_output.txt"

# Set the path to the actual output file
ACTUAL_OUTPUT_FILE="actual_output.txt"

# Scrub placeholder for hostname
SCRUB_PLACEHOLDER="\$\$\$SCRUBBED_HOSTNAME\$\$\$"

# Check if the script is invoked with the "--approve" option
if [ "$1" = "--approve" ]; then
  # Run the binary with the "--help" argument, replace the hostname, and save both stdout and stderr to the approved file
  { "$BINARY_PATH" --help 2>&1 | sed "s/$(hostname)/$SCRUB_PLACEHOLDER/g"; } > "$APPROVED_OUTPUT_FILE"
  echo "Approved output updated."
  exit 0
fi

# Run the binary with the "--help" argument and capture both stdout and stderr
{ "$BINARY_PATH" --help 2>&1 | sed "s/$(hostname)/$SCRUB_PLACEHOLDER/g"; } > "$ACTUAL_OUTPUT_FILE"

# Compare the current output with the approved output
if cmp -s "$ACTUAL_OUTPUT_FILE" "$APPROVED_OUTPUT_FILE"; then
  echo "Output matches the approved version."
  # Remove the actual output file if it matches the approved version
  rm "$ACTUAL_OUTPUT_FILE"
  exit 0
else
  echo "Error: Output has changed. Diff between actual and approved output:"
  diff "$APPROVED_OUTPUT_FILE" "$ACTUAL_OUTPUT_FILE"
  echo "Actual output saved to $ACTUAL_OUTPUT_FILE. Run the script with --approve option to update the approved output."
  exit 1
fi

