#!/bin/sh
#
# Finnish Meteorological Institute / Mikko Aalto (2014)
# Modified by Elmeri Nurmi (2017) and Mikael Hasu (2025)
# Adedd pbzip2, remember to install it.
#
# SmartMet Data Ingestion Module for WRF Model


DOMAIN=d02
OUT=/smartmet/data/wrf
CNF=/smartmet/run/data/wrf/cnf
EDITOR=/smartmet/editor/in

#Check the input
if [ $# -ne 2 ];
then
  echo " RUN [00,06,12,18] and domain [d01,d02] ?"
  exit 0
fi

RUN=$1
DOMAIN=$2

if [ $DOMAIN = d01 ]
then
  PRODUCER=61
  DOMAINNAME=large
else
  PRODUCER=60
  DOMAINNAME=small
fi

#UTCHOUR=$(date -u +%H -d '-3 hours')
UTCHOUR=$(date -u +%H)
DATE=$(date -u +%Y%m%d${RUN} -d '-7 hours')
TMP=/smartmet/tmp/data/wrf/$DOMAIN/$DATE/
LOGFILE=/smartmet/logs/data/wrf${DOMAIN}_${RUN}.log
OUTNAME=${DATE}00_wrf_${DOMAINNAME}

# Log everything
exec &> $LOGFILE

echo $(date)

mkdir -p $OUT/surface/querydata
mkdir -p $OUT/pressure/querydata

# Check that we don't already have this analysis time
if [ -e $OUT/surface/querydata/${OUTNAME}_surface.sqd ]; then
    echo Model for time $DATE exists already!
    exit 0
fi

mkdir -p $TMP/grib
cd $TMP/grib

echo "Moving files from incoming...."
mv /smartmet/data/incoming/wrf/${DOMAIN}/${DATE}/WRFPRS* .
if [ $? -ne 0 ]
then
    echo "error with mv to tmp"
fi
echo "done"


echo "Analysis time: $DATE"
echo "Model Run: $RUN"

echo "Converting grib files to qd files..."
# Surface parameters
gribtoqd -d -c $CNF/wrf-gribtoqd.cnf -n -t -L 1 -p "${PRODUCER},WRF Surface" -o $TMP/${OUTNAME}.sqd $TMP/grib/
# Pressure levels
gribtoqd -d -c $CNF/wrf-gribtoqd.cnf -n -t -L 100 -p "${PRODUCER},WRF Pressure" -o $TMP/${OUTNAME}.sqd $TMP/grib/
echo "done"

# Postprocess precipitation mm/h
qdscript -a 353 $CNF/st.surface.d/rr1h-353.st < $TMP/${OUTNAME}.sqd_levelType_1 > $TMP/${OUTNAME}.sqd_levelType_1_tmp

# Taking the surface and pressure data
mv -f $TMP/$OUTNAME.sqd_levelType_1_tmp $TMP/${OUTNAME}_surface.sqd.tmp
mv -f $TMP/$OUTNAME.sqd_levelType_100 $TMP/${OUTNAME}_pressure.sqd.tmp

# Create querydata totalWind and WeatherAndCloudiness objects
echo "Creating Wind and Weather objects:"
qdversionchange -w 0 7 < $TMP/${OUTNAME}_pressure.sqd.tmp > $TMP/${OUTNAME}_pressure.sqd
qdversionchange -a -w 1 7 < $TMP/${OUTNAME}_surface.sqd.tmp > $TMP/${OUTNAME}_surface.sqd
echo "done"

# Correct the Origin time for d02(small) domain.
if [ $DOMAIN = d02 ]; then
  echo -n "Changing origin time (${DATE}) for d02 files"
  qdset -T ${DATE}00 $TMP/${OUTNAME}_surface.sqd
  qdset -T ${DATE}00 $TMP/${OUTNAME}_pressure.sqd
else
  echo -n "No need to change origin time for d01 files"
fi

#
# Copy files to SmartMet Workstation and SmartMet Production directories
#

if [ -s $TMP/${OUTNAME}_surface.sqd ]; then
    echo -n "Compressing with pbzip2..."
    pbzip2 -p8 -k $TMP/${OUTNAME}_surface.sqd & pbzip2 -p8 -k $TMP/${OUTNAME}_pressure.sqd
    echo "done"

    echo -n "Copying file to SmartMet Production..."
    mv -f $TMP/${OUTNAME}_surface.sqd $OUT/surface/querydata/${OUTNAME}_surface.sqd
    mv -f $TMP/${OUTNAME}_surface.sqd.bz2 $EDITOR/
    echo "done"
    echo "Created files: ${OUTNAME}_surface.sqd"
    echo -n "Copying file to SmartMet Production..."
    mv -f $TMP/${OUTNAME}_pressure.sqd $OUT/pressure/querydata/${OUTNAME}_pressure.sqd
    mv -f $TMP/${OUTNAME}_pressure.sqd.bz2 $EDITOR/
    echo "done"
    echo "Created files: ${OUTNAME}_pressure.sqd"
fi

# Clean up the mess
rm -rf $TMP

echo $(date)
~

