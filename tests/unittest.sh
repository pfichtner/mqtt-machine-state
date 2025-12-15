#!/usr/bin/env bash
set -euo pipefail

echo "Running Go unit tests..."

# Go to the repository root
cd "$(dirname "$0")/.."

# Run all Go tests, including verbose output
go test ./... -v

