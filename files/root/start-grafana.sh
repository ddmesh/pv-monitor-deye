#!/bin/bash

GRAFANA_BASE="/root/grafana/data"


# Das Datenverzeichniss für Grafana habe ich im Homeverzeichniss von Root
mkdir -p ${GRAFANA_BASE}

# start docker as deamon. das fuellt auch das datenverzeichniss
docker run -d \
	--name grafana \
	--restart=always \
	-u $(id -u) \
	-v "${GRAFANA_BASE}:/var/lib/grafana" \
	-p 80:3000 \
	grafana/grafana-oss


