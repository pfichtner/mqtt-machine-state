package main

import (
	"fmt"
	"os"
	"os/signal"
	"path/filepath"
	"time"

	"github.com/eclipse/paho.mqtt.golang"
	"github.com/spf13/pflag"
	"github.com/spf13/viper"
)

var (
	configFile string
	brokerHost string
	port       int
	topic      string
	retained   bool
	qos        int
)

func init() {
	pflag.StringVarP(&configFile, "config", "c", "", "Config file name")
	pflag.StringVarP(&brokerHost, "broker", "b", "localhost", "MQTT broker host")
	pflag.IntVarP(&port, "port", "p", 1883, "MQTT broker port")
	pflag.StringVarP(&topic, "topic", "t", "$hostname/status", "MQTT topic")
	pflag.BoolVarP(&retained, "retained", "r", false, "Whether messages should be retained")
	pflag.IntVarP(&qos, "qos", "q", 0, "Quality of Service (QoS) level")
	pflag.CommandLine.SortFlags = false

	pflag.Parse()

	// Load configuration from file if provided
	if configFile != "" {
		configFile = os.ExpandEnv(configFile)
		viper.SetConfigFile(configFile)
		if filepath.Ext(configFile) == ".conf" {
			viper.SetConfigType("env")
		}
		if err := viper.ReadInConfig(); err != nil {
			fmt.Println("Error reading config file:", err)
			os.Exit(1)
		}
	}

	// Bind config values to pflag (if not provided via command line)
	viper.BindPFlag("broker", pflag.Lookup("broker"))
	viper.BindPFlag("port", pflag.Lookup("port"))
	viper.BindPFlag("topic", pflag.Lookup("topic"))
	viper.BindPFlag("retained", pflag.Lookup("retained"))
	viper.BindPFlag("qos", pflag.Lookup("qos"))
}

func main() {
	// Use viper.GetString, viper.GetInt, etc., to get configuration values
	brokerHost = viper.GetString("broker")
	port = viper.GetInt("port")
	topic := ExpandTopic(viper.GetString("topic"))
	retained = viper.GetBool("retained")
	qos = viper.GetInt("qos")

	brokerURL := fmt.Sprintf("tcp://%s:%d", brokerHost, port)

	opts := mqtt.NewClientOptions()
	opts.AddBroker(brokerURL)
	opts.SetAutoReconnect(false)
	opts.SetKeepAlive(2 * time.Second)
	opts.SetConnectionLostHandler(func(client mqtt.Client, err error) {
	    for !client.IsConnected() {
		if token := client.Connect(); token.WaitTimeout(5 * time.Second) && token.Error() != nil {
		    time.Sleep(2 * time.Second)
		} else {
		    token := client.Publish(topic, uint8(qos), retained, "online")
		    token.Wait()
		}
	    }
	})

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
		// Publish "offline" before disconnecting
		token := client.Publish(topic, uint8(qos), retained, "offline")
		token.Wait()

		client.Disconnect(250)
		os.Exit(0)
	}()

	// Keep the program running until manually terminated
	select {}
}

