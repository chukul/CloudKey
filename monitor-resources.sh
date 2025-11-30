#!/bin/bash

# Resource monitoring script for CloudKey
# Monitors CPU, Memory, and Energy usage

echo "=== CloudKey Resource Monitor ==="
echo "Starting monitoring... (Press Ctrl+C to stop)"
echo ""

# Find CloudKey process
get_pid() {
    pgrep -x "CloudKey" | head -1
}

# Wait for app to start
echo "Waiting for CloudKey to start..."
while [ -z "$(get_pid)" ]; do
    sleep 1
done

PID=$(get_pid)
echo "Found CloudKey (PID: $PID)"
echo ""

# Create log file
LOG_FILE="resource_monitor_$(date +%Y%m%d_%H%M%S).log"
echo "Logging to: $LOG_FILE"
echo ""

# Header
printf "%-10s %-10s %-10s %-15s %-10s\n" "Time" "CPU%" "Memory" "Threads" "Energy"
printf "%-10s %-10s %-10s %-15s %-10s\n" "Time" "CPU%" "Memory" "Threads" "Energy" > "$LOG_FILE"
echo "------------------------------------------------------------"

# Monitor loop
COUNTER=0
while true; do
    PID=$(get_pid)
    
    if [ -z "$PID" ]; then
        echo "CloudKey stopped. Exiting..."
        break
    fi
    
    # Get CPU and Memory
    CPU=$(ps -p $PID -o %cpu= | xargs)
    MEM=$(ps -p $PID -o rss= | xargs)
    MEM_MB=$((MEM / 1024))
    THREADS=$(ps -p $PID -o thcount= | xargs)
    
    # Get energy impact (macOS specific)
    ENERGY=$(ps -p $PID -o %cpu= | awk '{printf "%.1f", $1/10}')
    
    # Current time
    TIME=$(date +%H:%M:%S)
    
    # Print to console
    printf "%-10s %-10s %-10s %-15s %-10s\n" "$TIME" "${CPU}%" "${MEM_MB}MB" "$THREADS" "$ENERGY"
    
    # Log to file
    printf "%-10s %-10s %-10s %-15s %-10s\n" "$TIME" "${CPU}%" "${MEM_MB}MB" "$THREADS" "$ENERGY" >> "$LOG_FILE"
    
    # Calculate averages every 60 seconds
    COUNTER=$((COUNTER + 1))
    if [ $((COUNTER % 12)) -eq 0 ]; then
        echo "------------------------------------------------------------"
        AVG_CPU=$(tail -12 "$LOG_FILE" | awk '{sum+=$2} END {printf "%.1f", sum/12}')
        AVG_MEM=$(tail -12 "$LOG_FILE" | awk '{sum+=$3} END {printf "%.0f", sum/12}')
        echo "Last 60s Average: CPU=${AVG_CPU}% Memory=${AVG_MEM}MB"
        echo "------------------------------------------------------------"
    fi
    
    sleep 5
done

echo ""
echo "=== Monitoring Complete ==="
echo "Log saved to: $LOG_FILE"
echo ""
echo "Generating summary..."

# Generate summary
TOTAL_SAMPLES=$(wc -l < "$LOG_FILE" | xargs)
TOTAL_SAMPLES=$((TOTAL_SAMPLES - 1)) # Exclude header

if [ $TOTAL_SAMPLES -gt 0 ]; then
    AVG_CPU=$(tail -n +2 "$LOG_FILE" | awk '{sum+=$2} END {printf "%.1f", sum/NR}')
    MAX_CPU=$(tail -n +2 "$LOG_FILE" | awk 'BEGIN{max=0} {if($2>max) max=$2} END {printf "%.1f", max}')
    AVG_MEM=$(tail -n +2 "$LOG_FILE" | awk '{sum+=$3} END {printf "%.0f", sum/NR}')
    MAX_MEM=$(tail -n +2 "$LOG_FILE" | awk 'BEGIN{max=0} {if($3>max) max=$3} END {printf "%.0f", max}')
    
    echo "=== Summary ==="
    echo "Duration: $((TOTAL_SAMPLES * 5)) seconds ($TOTAL_SAMPLES samples)"
    echo "CPU Usage:"
    echo "  Average: ${AVG_CPU}%"
    echo "  Peak: ${MAX_CPU}%"
    echo "Memory Usage:"
    echo "  Average: ${AVG_MEM}MB"
    echo "  Peak: ${MAX_MEM}MB"
    echo ""
    
    # Analysis
    echo "=== Analysis ==="
    if (( $(echo "$AVG_CPU > 10" | bc -l) )); then
        echo "⚠️  HIGH CPU: Average CPU usage is high (${AVG_CPU}%)"
        echo "   Recommendation: Check for timer frequency, unnecessary updates"
    else
        echo "✅ CPU: Good (${AVG_CPU}%)"
    fi
    
    if (( $(echo "$AVG_MEM > 150" | bc -l) )); then
        echo "⚠️  HIGH MEMORY: Average memory usage is high (${AVG_MEM}MB)"
        echo "   Recommendation: Check for memory leaks, cache size"
    else
        echo "✅ Memory: Good (${AVG_MEM}MB)"
    fi
fi
