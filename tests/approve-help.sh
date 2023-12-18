#!/bin/bash

# Set the path to the binary
BINARY_NAME="$1"
BINARY_PATH="../$BINARY_NAME"

# Set the path to the approved output file
APPROVED_OUTPUT_FILE="approved_output.txt"

# Set the path to the actual output file
ACTUAL_OUTPUT_FILE="actual_output.txt"

# Scrub placeholders for hostname and binary name
SCRUB_HOSTNAME_PLACEHOLDER="\$\$\$SCRUBBED_HOSTNAME\$\$\$"
SCRUB_BINARY_NAME_PLACEHOLDER="\$\$\$SCRUBBED_BINARY_NAME\$\$\$"

# Check if the script is invoked with the "--approve" option
if [ "$BINARY_NAME" = "--approve" ]; then
  echo "Error: Missing binary name. Usage: $0 <binary_name>"
  exit 1
fi

if [ "$2" = "--approve" ]; then
  # Run the binary with the "--help" argument, replace the hostname and binary name, and save both stdout and stderr to the approved file
  { "$BINARY_PATH" --help 2>&1 | sed -e "s/$(hostname)/$SCRUB_HOSTNAME_PLACEHOLDER/g" -e "s/$BINARY_NAME/$SCRUB_BINARY_NAME_PLACEHOLDER/g"; } > "$APPROVED_OUTPUT_FILE"
  echo "Approved output updated."
  exit 0
fi

# Run the binary with the "--help" argument and capture both stdout and stderr
{ "$BINARY_PATH" --help 2>&1 | sed -e "s/$(hostname)/$SCRUB_HOSTNAME_PLACEHOLDER/g" -e "s/$BINARY_NAME/$SCRUB_BINARY_NAME_PLACEHOLDER/g"; } > "$ACTUAL_OUTPUT_FILE"

# Compare the current output with the approved output
if diff -w "$APPROVED_OUTPUT_FILE" "$ACTUAL_OUTPUT_FILE" > /dev/null; then
  echo "Output matches the approved version."
  # Remove the actual output file if it matches the approved version
  rm "$ACTUAL_OUTPUT_FILE"
  exit 0
else
  echo "Error: Output has changed. Diff between actual and approved output:"
  diff -w "$APPROVED_OUTPUT_FILE" "$ACTUAL_OUTPUT_FILE"
  echo "Actual output saved to $ACTUAL_OUTPUT_FILE. Run the script with --approve option to update the approved output."
  exit 1
fi

