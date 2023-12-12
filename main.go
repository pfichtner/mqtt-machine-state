package main

import (
	"flag"
	"fmt"
	"os"
	"os/signal"
	"time"

	"github.com/eclipse/paho.mqtt.golang"
)

func main() {
	var (
		brokerHost string
		port       int
		topic      string
		retained   bool
		qos        int
	)

	// Compute the default topic value
	hostname, err := os.Hostname()
	if err != nil {
		fmt.Println("Error getting hostname:", err)
		os.Exit(1)
	}
	defaultTopic := fmt.Sprintf("%s/status", hostname)

	// Parse command-line arguments
	flag.StringVar(&brokerHost, "broker", "localhost", "MQTT broker host")
	flag.IntVar(&port, "port", 1883, "MQTT broker port")
	flag.StringVar(&topic, "topic", defaultTopic, "MQTT topic")
	flag.BoolVar(&retained, "retained", false, "Whether messages should be retained")
	flag.IntVar(&qos, "qos", 0, "Quality of Service (QoS) level")

	flag.Parse()

	brokerURL := fmt.Sprintf("tcp://%s:%d", brokerHost, port)

	opts := mqtt.NewClientOptions()
	opts.AddBroker(brokerURL)
	opts.SetClientID("mqtt-client")
	opts.SetAutoReconnect(true)
	opts.SetKeepAlive(2 * time.Second)

	// Set Last Will and Testament (LWT)
	opts.SetWill(topic, "offline", uint8(qos), retained)

	client := mqtt.NewClient(opts)
	if token := client.Connect(); token.Wait() && token.Error() != nil {
		fmt.Println(token.Error())
		os.Exit(1)
	}

	// Publish "online" to the specified topic
	token := client.Publish(topic, uint8(qos), retained, "online")
	token.Wait()

	// Handle Ctrl+C to disconnect gracefully
	c := make(chan os.Signal, 1)
	signal.Notify(c, os.Interrupt)

	// Use a goroutine to handle the signal
	go func() {
		<-c
		fmt.Println("\nDisconnecting from the MQTT broker...")

		// Publish "offline" before disconnecting
		token := client.Publish(topic, uint8(qos), retained, "offline")
		token.Wait()

		client.Disconnect(250)
		os.Exit(0)
	}()

	// Keep the program running until manually terminated
	select {}
}

