#!/bin/bash

# Enhanced CloudKey Resource Monitor
# Tracks CPU, Memory, Energy Impact, and Thread Count

APP_NAME="CloudKey"
DURATION=120  # Monitor for 2 minutes
INTERVAL=2    # Sample every 2 seconds

echo "=== CloudKey Resource Monitor ==="
echo "Duration: ${DURATION}s | Interval: ${INTERVAL}s"
echo "Started: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# Check if app is running
if ! pgrep -x "$APP_NAME" > /dev/null; then
    echo "❌ $APP_NAME is not running"
    exit 1
fi

echo "✅ $APP_NAME is running"
echo ""

# Headers
printf "%-8s %-8s %-10s %-8s %-12s %-8s\n" "TIME" "CPU%" "MEM(MB)" "THREADS" "ENERGY" "STATUS"
echo "------------------------------------------------------------------------"

# Tracking variables
total_cpu=0
total_mem=0
total_energy=0
samples=0
max_cpu=0
max_mem=0

# Monitor loop
end_time=$(($(date +%s) + DURATION))
while [ $(date +%s) -lt $end_time ]; do
    # Get process stats
    stats=$(ps -p $(pgrep -x "$APP_NAME") -o %cpu=,%mem=,rss=,thcount= 2>/dev/null)
    
    if [ -n "$stats" ]; then
        cpu=$(echo $stats | awk '{print $1}')
        mem_pct=$(echo $stats | awk '{print $2}')
        mem_kb=$(echo $stats | awk '{print $3}')
        threads=$(echo $stats | awk '{print $4}')
        
        # Convert memory to MB
        mem_mb=$(echo "scale=1; $mem_kb / 1024" | bc)
        
        # Get energy impact (macOS specific)
        energy=$(top -l 1 -pid $(pgrep -x "$APP_NAME") -stats pid,power 2>/dev/null | tail -1 | awk '{print $2}')
        if [ -z "$energy" ]; then
            energy="N/A"
        fi
        
        # Determine status
        status="IDLE"
        if (( $(echo "$cpu > 10" | bc -l) )); then
            status="ACTIVE"
        fi
        
        # Print current stats
        timestamp=$(date '+%H:%M:%S')
        printf "%-8s %-8s %-10s %-8s %-12s %-8s\n" "$timestamp" "$cpu" "$mem_mb" "$threads" "$energy" "$status"
        
        # Track totals
        total_cpu=$(echo "$total_cpu + $cpu" | bc)
        total_mem=$(echo "$total_mem + $mem_mb" | bc)
        if [ "$energy" != "N/A" ]; then
            total_energy=$(echo "$total_energy + $energy" | bc)
        fi
        samples=$((samples + 1))
        
        # Track maximums
        if (( $(echo "$cpu > $max_cpu" | bc -l) )); then
            max_cpu=$cpu
        fi
        if (( $(echo "$mem_mb > $max_mem" | bc -l) )); then
            max_mem=$mem_mb
        fi
    fi
    
    sleep $INTERVAL
done

echo "------------------------------------------------------------------------"
echo ""
echo "=== ANALYSIS ==="

# Calculate averages
if [ $samples -gt 0 ]; then
    avg_cpu=$(echo "scale=2; $total_cpu / $samples" | bc)
    avg_mem=$(echo "scale=1; $total_mem / $samples" | bc)
    avg_energy=$(echo "scale=2; $total_energy / $samples" | bc)
    
    echo "CPU Usage:"
    echo "  Average: ${avg_cpu}%"
    echo "  Peak:    ${max_cpu}%"
    echo ""
    echo "Memory Usage:"
    echo "  Average: ${avg_mem} MB"
    echo "  Peak:    ${max_mem} MB"
    echo ""
    echo "Energy Impact:"
    echo "  Average: ${avg_energy}"
    echo ""
    echo "Samples: $samples"
    echo ""
    
    # Performance assessment
    echo "=== PERFORMANCE ASSESSMENT ==="
    if (( $(echo "$avg_cpu < 5" | bc -l) )); then
        echo "✅ CPU: Excellent (< 5%)"
    elif (( $(echo "$avg_cpu < 10" | bc -l) )); then
        echo "✅ CPU: Good (5-10%)"
    elif (( $(echo "$avg_cpu < 20" | bc -l) )); then
        echo "⚠️  CPU: Moderate (10-20%) - Room for optimization"
    else
        echo "❌ CPU: High (> 20%) - Optimization needed"
    fi
    
    if (( $(echo "$avg_mem < 100" | bc -l) )); then
        echo "✅ Memory: Excellent (< 100 MB)"
    elif (( $(echo "$avg_mem < 150" | bc -l) )); then
        echo "✅ Memory: Good (100-150 MB)"
    elif (( $(echo "$avg_mem < 200" | bc -l) )); then
        echo "⚠️  Memory: Moderate (150-200 MB)"
    else
        echo "❌ Memory: High (> 200 MB) - Check for leaks"
    fi
    
    if [ "$avg_energy" != "0" ]; then
        if (( $(echo "$avg_energy < 10" | bc -l) )); then
            echo "✅ Energy: Low impact (< 10)"
        elif (( $(echo "$avg_energy < 30" | bc -l) )); then
            echo "⚠️  Energy: Moderate impact (10-30)"
        else
            echo "❌ Energy: High impact (> 30)"
        fi
    fi
fi

echo ""
echo "Completed: $(date '+%Y-%m-%d %H:%M:%S')"
