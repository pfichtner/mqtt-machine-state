package main

import (
	"bytes"
	"os"
	"strings"
	"testing"

	"github.com/spf13/viper"
)

func TestExpandTopicWarning(t *testing.T) {
	var buf bytes.Buffer

	// Setup Viper with a topic containing an unknown variable
	viper.Set("topic", "$hostname_$unknown/status")
	rawTopic := viper.GetString("topic")

	// Call function and capture output
	_ = ExpandTopic(rawTopic, &buf)

	output := buf.String()
	if !strings.Contains(output, "Warning: topic contains unexpanded variables:") {
		t.Errorf("Expected warning not printed, got: %s", output)
	}
}

func TestExpandTopicHostname(t *testing.T) {
	var buf bytes.Buffer
	hostname, _ := os.Hostname()
	rawTopic := "$hostname/status"

	result := ExpandTopic(rawTopic, &buf)

	if !strings.HasPrefix(result, hostname) {
		t.Errorf("Expected topic to start with hostname %q, got: %q", hostname, result)
	}
	if !strings.HasSuffix(result, "/status") {
		t.Errorf("Expected topic to end with /status, got: %q", result)
	}

	// Ensure no warning printed
	output := buf.String()
	if output != "" {
		t.Errorf("Did not expect any warning, got: %s", output)
	}
}
