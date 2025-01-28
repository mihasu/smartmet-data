#!/bin/sh
#Script for converting local obs to querydata
#2023-11-08 / Janne Kauhanen / FMI
#2025-01-28 / Mikael Hasu, FMI / Download json data and save as csv
WORKING_DIR='/smartmet/tmp/data/local_obs';
SMARTMET_DIR='/smartmet/editor/in';
STATION_FILE='/smartmet/run/data/local_obs/cnf/all_stations.csv';
STATION_URL="https://wwcs.tj/observations/stations/"
DATA_URL="https://wwcs.tj/observations/smartmet/?siteID="
TIMESTAMP=`date +%Y%m%d%H%M` ;
WORKING_FILE=${WORKING_DIR}/local_obs_${TIMESTAMP}.csv;
QD_FILE=${SMARTMET_DIR}/${TIMESTAMP}_tajikistan_local_obs.sqd

echo "getting station data for db at $PWD DATE: $TIMESTAMP";
curl -s $STATION_URL | jq -r '.[] | [.siteID, .siteID, .longitude, .latitude, .siteName] | @csv' | sed 's/"//g' > $STATION_FILE

echo "Downloading site data for each station..."
tail -n +2 $STATION_FILE | while IFS=, read -r siteID _; do
    echo "Processing siteID: $siteID"
    curl -s "${DATA_URL}${siteID}" | jq -r '.[] |   
        [   .siteID,
            (.datetime | strptime("%a, %d %b %Y %H:%M:%S %Z") | strftime("%Y%m%dT%H%M%S")),
            (.data[] | select(.machineName == "air_temperature") | .value // ""),
            (.data[] | select(.machineName == "relative_humidity") | .value // ""),
            (.data[] | select(.machineName == "air_pressure") | .value // ""),
            (.data[] | select(.machineName == "dew_point") | .value // ""),
            (.data[] | select(.machineName == "precipitation") | .value // ""),
            (.data[] | select(.machineName == "wind_direction") | .value // ""),
            (.data[] | select(.machineName == "wind_speed") | .value // "")
        ] | @csv' | sed 's/"//g' >> $WORKING_FILE
done

echo "Replacing precipitation -999 with empty string";
sed -i 's/-999//g' ${WORKING_FILE};echo "Executing csv2qd";
echo $QD_FILE
csv2qd -v -S ${STATION_FILE} --order=idtime -p Temperature,Humidity,Pressure,DewPoint,PrecipitationAmount,WindDirection,WindSpeedMS -i ${WORKING_FILE} -o ${QD_FILE}

echo "Resulting file: ${QD_FILE}";