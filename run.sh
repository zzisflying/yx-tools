#!/bin/bash

APP=/app
DATA=$APP/data

mkdir -p $DATA

NOW=$(date +%Y%m%d-%H%M%S)
RESULT=$DATA/result-$NOW.csv

echo "========== $(date) ==========" >> $DATA/run.log

#
# 多地区测速
#
REGIONS="NRT ICN HKG CU"

rm -f $APP/all.csv

for REGION in $REGIONS
do
    echo "$(date '+%F %T') Test $REGION" \
        >> $DATA/run.log

    python3 $APP/cloudflare_speedtest.py \
        --mode normal \
        --region $REGION \
        --count 5 \
        >> $DATA/run.log 2>&1

    if [ -f $APP/result.csv ]; then
        if [ ! -f $APP/all.csv ]; then
            cp $APP/result.csv $APP/all.csv
        else
            tail -n +2 $APP/result.csv >> $APP/all.csv
        fi
    fi
done

if [ -f $APP/all.csv ]; then
    mv $APP/all.csv $RESULT

    python3 $APP/upload-cfst.py $RESULT \
        >> $DATA/run.log 2>&1
else
    echo "$(date '+%F %T') no result file" \
        >> $DATA/run.log
fi

#
# 保留最近7次测速结果
#
ls -1t $DATA/result-*.csv 2>/dev/null \
| tail -n +8 \
| xargs -r rm -f
