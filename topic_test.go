package main

import (
	"bytes"
	"os"
	"strings"
	"testing"

	"github.com/spf13/viper"
)

func TestExpandTopicWarning(t *testing.T) {
	// Capture stdout
	var buf bytes.Buffer
	old := os.Stdout
	os.Stdout = &buf
	defer func() { os.Stdout = old }()

	// Setup Viper with a topic containing an unknown variable
	viper.Set("topic", "$hostname_$unknown/status")

	rawTopic := viper.GetString("topic")
	_ = ExpandTopic(rawTopic) // should print a warning

	output := buf.String()
	if !strings.Contains(output, "Warning: topic contains unexpanded variables:") {
		t.Errorf("Expected warning not printed, got: %s", output)
	}
}
