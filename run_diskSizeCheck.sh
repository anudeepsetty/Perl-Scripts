#!/bin/bash

CLUSTERS=(
        "DevLogs_lasvegas"
        "DevEnterprise_lasvegas"
        "Dev_Logs_dallas"
        "Dev_Enterprise_dallas"
        )

for CLUSTER in "${CLUSTERS[@]}";do
            echo "Starting metrics collection for: $CLUSTER"
            echo "perl /apps/c1/scripts/diskSizeCheck.pl $CLUSTER"
            perl /apps/c1/scripts/diskSizeCheck.pl "$CLUSTER"

                if [ $? -eq 0 ]; then
                        echo "Successfully processed $CLUSTER"
                else
                        echo "Error: Failed to process $CLUSTER"
                fi
done
echo "All clusters processed."
