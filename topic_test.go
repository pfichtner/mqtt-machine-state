package main

import (
	"bytes"
	"io"
	"os"
	"strings"
	"testing"

	"github.com/spf13/viper"
)

func TestExpandTopicWarning(t *testing.T) {
	// Create a pipe to capture stdout
	r, w, err := os.Pipe()
	if err != nil {
		t.Fatalf("Failed to create pipe: %v", err)
	}

	oldStdout := os.Stdout
	os.Stdout = w
	defer func() { os.Stdout = oldStdout }()

	// Setup Viper with a topic containing an unknown variable
	viper.Set("topic", "$hostname_$unknown/status")
	rawTopic := viper.GetString("topic")

	// Call the function that prints the warning
	_ = ExpandTopic(rawTopic)

	// Close writer and read output
	w.Close()
	var buf bytes.Buffer
	_, err = io.Copy(&buf, r)
	if err != nil {
		t.Fatalf("Failed to read pipe: %v", err)
	}

	output := buf.String()
	if !strings.Contains(output, "Warning: topic contains unexpanded variables:") {
		t.Errorf("Expected warning not printed, got: %s", output)
	}
}
