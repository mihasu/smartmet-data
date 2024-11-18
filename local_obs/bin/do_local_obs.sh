#!/bin/sh
#Script for converting local obs (from wrf.meteo.kg) to querydata
#2023-11-08 / Janne Kauhanen / FMI
#Data is fetched from wrf.meteo.kg by s
BIN_DIR='/smartmet/run/data/local_obs/bin';
CNF_DIR='/smartmet/run/data/local_obs/cnf';
CSV_FILE_DIR='/smartmet/data/incoming/local_obs';
WORKING_DIR='/smartmet/tmp/data/local_obs';
SMARTMET_DIR='/smartmet/editor/in';
STATION_FILE='/smartmet/run/data/local_obs/cnf/all_stations.csv';

TIMESTAMP=`date +%Y%m%d%H%M` ;
WORKING_FILE=${WORKING_DIR}/local_obs_${TIMESTAMP}.csv;
QD_FILE=${SMARTMET_DIR}/${TIMESTAMP}_uzbekistan_local_obs.sqd

#Run script fetching data from wrf.meteo.kg
cd $CSV_FILE_DIR
echo "getting station data for db at $PWD DATE: $TIMESTAMP";
wget -O ${CNF_DIR}/all_stations.csv "http://10.12.12.15:8085/api/csv/all-stations"
wget -O local_obs_${TIMESTAMP}.csv "http://10.12.12.15:8085/api/csv/stations-data"
tail -n +2 local_obs_${TIMESTAMP}.csv > $WORKING_FILE;
echo "Replacing precipitation -999 with empty string";
sed -i 's/-999//g' ${WORKING_FILE};echo "Executing csv2qd";

echo $QD_FILE
csv2qd -v -S ${STATION_FILE} --order=idtime -p Temperature,Humidity,Pressure,DewPoint,PrecipitationAmount,WindDirection,WindSpeedMS -i ${WORKING_FILE} -o ${QD_FILE}

#rm ${WORKING_FILE}
echo "Resulting file: ${QD_FILE}";

#cp ${QD_FILE} ${DATA_DIR};
#echo "copied ${QD_FILE} to ${DATA_DIR}";
