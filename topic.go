package main

import (
	"fmt"
	"io"
	"os"
)

// ExpandTopic replaces $hostname in the topic string.
// Prints a warning if there are unexpanded variables.
func ExpandTopic(rawTopic string, out io.Writer) string {
	hostname, err := os.Hostname()
	if err != nil {
		fmt.Fprintln(out, "Error getting hostname:", err)
		os.Exit(1)
	}

	os.Setenv("hostname", hostname)
	expanded := os.ExpandEnv(rawTopic)

	// Warn if expansion didn't change the string
	if expanded == rawTopic {
		fmt.Fprintln(out, "Warning: topic contains unexpanded variables:", rawTopic)
	}

	return expanded
}

