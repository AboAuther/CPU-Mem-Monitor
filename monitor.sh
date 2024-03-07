#!/bin/bash

# Ensure we have an argument to run
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 'command to run'"
    exit 1
fi

# Run the command in the background
PID=$!

# Define the output file
OUTPUT_FILE="resource_usage.txt"

# Write header to file
echo "Timestamp,CPU Usage (%),Total Memory Usage (GB)" > $OUTPUT_FILE

# Function to get memory usage in GB
get_mem_usage() {
    # Get memory usage in KB and convert it to GB
    free | grep Mem | awk '{print $3/1024/1024}'
}

# Function to get aggregate CPU usage
get_aggregate_cpu_usage() {
    PREV_TOTAL=0
    PREV_IDLE=0
    while read -r LINE; do
        [[ $LINE != cpu* ]] && continue
        USER_TIME=$(echo $LINE | awk '{print $2}')
        NICE_TIME=$(echo $LINE | awk '{print $3}')
        SYSTEM_TIME=$(echo $LINE | awk '{print $4}')
        IDLE_TIME=$(echo $LINE | awk '{print $5}')

        CORE_TOTAL=$((USER_TIME + NICE_TIME + SYSTEM_TIME + IDLE_TIME))
        PREV_TOTAL=$((PREV_TOTAL + CORE_TOTAL))
        PREV_IDLE=$((PREV_IDLE + IDLE_TIME))
    done < /proc/stat

    sleep 1

    NEXT_TOTAL=0
    NEXT_IDLE=0
    while read -r LINE; do
        [[ $LINE != cpu* ]] && continue
        USER_TIME=$(echo $LINE | awk '{print $2}')
        NICE_TIME=$(echo $LINE | awk '{print $3}')
        SYSTEM_TIME=$(echo $LINE | awk '{print $4}')
        IDLE_TIME=$(echo $LINE | awk '{print $5}')

        CORE_TOTAL=$((USER_TIME + NICE_TIME + SYSTEM_TIME + IDLE_TIME))
        NEXT_TOTAL=$((NEXT_TOTAL + CORE_TOTAL))
        NEXT_IDLE=$((NEXT_IDLE + IDLE_TIME))
    done < /proc/stat

    IDLE_DIFF=$((NEXT_IDLE - PREV_IDLE))
    TOTAL_DIFF=$((NEXT_TOTAL - PREV_TOTAL))
    USAGE=$((100 * (TOTAL_DIFF - IDLE_DIFF) / TOTAL_DIFF))

    CORE_COUNT=$(nproc)
    AGGREGATE_USAGE=$((USAGE * CORE_COUNT))

    echo $AGGREGATE_USAGE
}

# Monitor until our command finishes
while kill -0 $PID 2>/dev/null; do
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    CPU_USAGE=$(get_aggregate_cpu_usage)
    MEM_USAGE=$(get_mem_usage)
    echo "$TIMESTAMP,$CPU_USAGE,$MEM_USAGE" >> $OUTPUT_FILE
done

# Cleanup
wait $PID