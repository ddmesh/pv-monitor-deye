#!/bin/bash

# das script nutzt mqttx-cli um pv analage werte abzurufen.
# jede änderung wird direkt in die datenbank gepusht. das polling ist
# durch "mqttx-cli-deye-config.json" (deye docker container) definiert.
# kleinste zeit ist 60s. Irgendwo stand dass Deye alle 5min daten liefert.
#
# deye-docker -> mqtt-broker -> mqttx-cli -> graphite (via nc)
#
OUT="/tmp/mqttx-cli.out"
CONFIG="/root/mqttx-cli-deye-config.json"

# seconds after which data should be sent. should be same as mqttx gets data.
SEND_PERIODE_TIME=10

#-------------------------------------------------

# variable to remember displaying only one entry in syslog
LOGGER=0

# nach dem booten kommt mqttx-cli mit fehler zurueck, da die container noch nicht laufen.
# solange probieren, bis es geht.
while sleep 5
do
	logger -s -t "deye" "try to start mqttx-cli"

	# "jq -c" erzeugt pro "event" ein json objekt
	# "stdbuf -i0 -o0 -e0" ist notwendig, damit die ausgabe zu "while" nicht gepuffert wird
	/root/mqttx-cli sub --config ${CONFIG} | stdbuf -i0 -o0 -e0 jq --raw-output '"topic=\"\(.topic)\";value=\"\(.payload)\""' | while read line
	do
		if [ "$LOGGER" = "0" ]; then
			logger -s -t "deye" "got data from mqttx-cli: [$line]"
			LOGGER=1
		fi

		eval "${line}"
#echo "######  $topic  #######" >>/tmp/x

		# create and set all values as variables.
		var="${topic//\//_}"

		# replace some values
		[ "$value" = "online" ] && value=1
		[ "$value" = "offline" ] && value=0

		# set variablen
		eval "${var}=\"${value}\""
#		set | grep "^deye" > ${OUT}.env

		# deye/status kommt als erstes. wenn das kommt werde ich alle gesammelten
		# daten mit einem mal an die DB schicken, da jeder einzelne aufruf von "nc" recht lange dauert.
		# "deye/ac/temperature" ist das letzte verlaessliche topic, was empfangen wird. deye/status und deye/logger_status
		# kommen nicht zuverlaessig nach dem booten.

		if [ "${topic}" = "deye/ac/temperature" ]; then
#echo ">>>>>>>>>>>>######  $topic  #######" >>/tmp/x

			# berechne ups strom und überschreibe variablen mit falschen werten, die von deye kommen
			if [ -n "$deye_ac_ups_l1_voltage" -a -n "$deye_ac_ups_l2_voltage" -a -n "$deye_ac_ups_l3_voltage" ]; then
				calc="$deye_ac_ups_l1_power / $deye_ac_ups_l1_voltage"
				deye_ac_ups_l1_current=$(echo "scale=2;${calc}" | bc)
				calc="$deye_ac_ups_l2_power / $deye_ac_ups_l2_voltage"
				deye_ac_ups_l2_current=$(echo "scale=2;${calc}" | bc)
				calc="$deye_ac_ups_l3_power / $deye_ac_ups_l3_voltage"
				deye_ac_ups_l3_current=$(echo "scale=2;${calc}" | bc)
			fi

			# overwrite invalid values
			deye_ac_l1_power=${deye_ac_l1_ct_internal:=0}
			deye_ac_l2_power=${deye_ac_l2_ct_internal:=0}
			deye_ac_l3_power=${deye_ac_l3_ct_internal:=0}

			# berechne current
			if [ -n "$deye_ac_l1_voltage" -a -n "$deye_ac_l2_voltage" -a -n "$deye_ac_l3_voltage" ]; then
				calc="$deye_ac_l1_power / $deye_ac_l1_voltage"
				deye_ac_l1_current=$(echo "scale=2;${calc}" | bc)
				calc="$deye_ac_l2_power / $deye_ac_l2_voltage"
				deye_ac_l2_current=$(echo "scale=2;${calc}" | bc)
				calc="$deye_ac_l3_power / $deye_ac_l3_voltage"
				deye_ac_l3_current=$(echo "scale=2;${calc}" | bc)
			fi

			# berechne PV Total
			if [ -n "$deye_dc_pv1_power" -a -n "$deye_dc_pv2_power" -a -n "$deye_dc_pv3_power" -a -n "$deye_dc_pv4_power" ]; then
				calc="$deye_dc_pv1_power + $deye_dc_pv2_power + $deye_dc_pv3_power + $deye_dc_pv4_power"
				deye_dc_total_power=$(echo "scale=2;${calc}" | bc)
			fi

			# create string with all values and send it
			time="$(date +%s)"
			data=""
			for v in $(set | grep "^deye")
			do

				var="${v%%=*}"
				key="${var//_/.}"
				eval value="\$$var"

				data="${data}${key} ${value} ${time}\n"
			done

			echo "send data"
			printf "${data}"
			printf "${data}" > ${OUT}.send
			printf "${data}" | nc -w3 127.0.0.1 2003
			echo "sending finished"
		fi

	done
done
