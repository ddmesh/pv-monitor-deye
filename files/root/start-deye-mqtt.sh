#!/bin/bash


# Sammelt daten vom WR ein und sendet diese an einen MQTT broker.
# Der broker (mosquitto) läuft local auf dem orange pi

# https://github.com/kbialek/deye-inverter-mqtt
#
# deye-mqtt deye-docker.env anpassen:
#
#       MQTT_HOST=172.17.0.1
#       # sun-15k-sg01hp3-eu-am2
#       DEYE_LOGGER_IP_ADDRESS=<IP des Datenlogger Adapters>
#       DEYE_LOGGER_PORT=8899
#       DEYE_LOGGER_SERIAL_NUMBER=<Seriennummer des Datenlogger Adapters>
#       DEYE_LOGGER_PROTOCOL=tcp
#       DEYE_METRIC_GROUPS=deye_sg01hp3,deye_sg01hp3_battery,deye_sg01hp3_ups

docker run -d --name deye-mqtt --env-file deye-docker.env --restart always ghcr.io/kbialek/deye-inverter-mqtt
