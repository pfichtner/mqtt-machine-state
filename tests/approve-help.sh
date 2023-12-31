#!/bin/bash

# Set the path to the binary
BINARY_NAME="$1"
BINARY_PATH=$(realpath "../$BINARY_NAME")
REAL_BINARY_PATH="$BINARY_PATH"

# Check if the script is running on Windows
[[ "$(uname -s)" == MINGW* ]] && REAL_BINARY_PATH=$(echo "$REAL_BINARY_PATH" | sed 's,^/\(.\),\U\1:,;s/\//\\/g')

# Set the path to the approved output file
APPROVED_OUTPUT_FILE="approved_output.txt"

# Set the path to the actual output file
ACTUAL_OUTPUT_FILE="actual_output.txt"

# Scrub placeholders for hostname, binary name, and binary path
SCRUB_HOSTNAME_PLACEHOLDER="\$\$\$SCRUBBED_HOSTNAME\$\$\$"
SCRUB_BINARY_PATH_PLACEHOLDER="\$\$\$SCRUBBED_BINARY_PATH\$\$\$"

# Run the binary with the "--help" argument and capture both stdout and stderr
REAL_BINARY_PATH=$(echo "$REAL_BINARY_PATH" | sed 's|\\|\\\\|g')
{ "$BINARY_PATH" --help 2>&1 | sed -e "s|$(hostname)|$SCRUB_HOSTNAME_PLACEHOLDER|g" -e "s|$REAL_BINARY_PATH|$SCRUB_BINARY_PATH_PLACEHOLDER|g"; } > "$ACTUAL_OUTPUT_FILE"

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

