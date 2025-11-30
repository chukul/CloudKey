#!/bin/bash
APP_NAME="CloudKey"
DURATION=60
INTERVAL=2

if ! pgrep -x "$APP_NAME" > /dev/null; then
    echo "❌ $APP_NAME is not running"
    exit 1
fi

echo "Monitoring $APP_NAME for ${DURATION}s..."
printf "%-8s %-8s %-10s\n" "TIME" "CPU%" "MEM(MB)"
echo "--------------------------------"

total_cpu=0
samples=0
max_cpu=0

end_time=$(($(date +%s) + DURATION))
while [ $(date +%s) -lt $end_time ]; do
    stats=$(ps -p $(pgrep -x "$APP_NAME") -o %cpu=,rss= 2>/dev/null)
    
    if [ -n "$stats" ]; then
        cpu=$(echo $stats | awk '{print $1}')
        mem_kb=$(echo $stats | awk '{print $2}')
        mem_mb=$(echo "scale=1; $mem_kb / 1024" | bc)
        
        timestamp=$(date '+%H:%M:%S')
        printf "%-8s %-8s %-10s\n" "$timestamp" "$cpu" "$mem_mb"
        
        total_cpu=$(echo "$total_cpu + $cpu" | bc)
        samples=$((samples + 1))
        
        if (( $(echo "$cpu > $max_cpu" | bc -l) )); then
            max_cpu=$cpu
        fi
    fi
    
    sleep $INTERVAL
done

echo "--------------------------------"
if [ $samples -gt 0 ]; then
    avg_cpu=$(echo "scale=2; $total_cpu / $samples" | bc)
    echo "Average CPU: ${avg_cpu}%"
    echo "Peak CPU: ${max_cpu}%"
    echo "Samples: $samples"
fi
