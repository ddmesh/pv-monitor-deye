#!/bin/sh


d="$(date +"%Y-%m-%d-%H%M%S")"
BACKUP_DIR="backup"

echo "stopping container"
docker stop graphite grafana

sync

mkdir -p ${BACKUP_DIR}
tar cvzf "${BACKUP_DIR}/${d}-fullbackup.tgz" grafana graphite-data backup.sh collect-data.sh deye-docker.env mqttx-cli mqttx-cli-binaries mqttx-cli-deye-config.json start-deye-mqtt.sh start-grafana.sh start-graphite.sh

sync

echo "restarting container"
docker start graphite grafana
