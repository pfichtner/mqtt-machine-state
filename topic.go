package main

import (
	"fmt"
	"os"
	"strings"

	"github.com/spf13/viper"
)

// ExpandTopic replaces $hostname in the topic string.
// Prints a warning if there are unexpanded variables.
func ExpandTopic(rawTopic string) string {
	hostname, err := os.Hostname()
	if err != nil {
		fmt.Println("Error getting hostname:", err)
		os.Exit(1)
	}

	// Option 1: using os.ExpandEnv
	os.Setenv("hostname", hostname)
	expanded := os.ExpandEnv(rawTopic)

	// Option 2: alternatively, you could use strings.ReplaceAll
	// expanded := strings.ReplaceAll(rawTopic, "$hostname", hostname)

	// Warn if expansion didn't change the string
	if expanded == rawTopic {
		fmt.Println("Warning: topic contains unexpanded variables:", rawTopic)
	}

	return expanded
}

