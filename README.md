[![Go](https://github.com/pfichtner/mqtt-machine-state/actions/workflows/go.yml/badge.svg)](https://github.com/pfichtner/mqtt-machine-state/actions/workflows/go.yml)

# mqtt-machine-state

Send messages to mqtt broker on machine startups/shutdowns
This program does noting more than connecting to a mqtt broker, publishs a message ("online") and blocks until it gets killed (e.g. by ctrl+c). 
Before gettting stopped it publishes another message ("offline"). Additionally it registers this message as last will testament (LWT) for the case the connection get's interrupetd. 

## Ok, what's that for!?

I added this tiny program to the startup of my machines so each machine getting up and down publish their states to the mqtt broker, so you know which machines are up and which not. But the real value is that you can run automations on that. I have a server to which my workstations and servers can do their backups to. This backup server is not powered on permanently. When this server comes up the workstations should start doing there backups which now easily can be done by them by subscribing to the topic of the backup server (wait for the topic hostname-of-the-backupserver/status to be "online")

```
./mqttmachinestate -h
Usage of ./mqttmachinestate:
  -c, --config string   Config file name
  -b, --broker string   MQTT broker host (default "localhost")
  -p, --port int        MQTT broker port (default 1883)
  -t, --topic string    MQTT topic (default "$hostname/status")
  -r, --retained        Whether messages should be retained
  -q, --qos int         Quality of Service (QoS) level
pflag: help requested
```
