#!/bin/bash
# Resource Monitoring Script for MeetingMinutesATS
# This script monitors system resources and logs them to a file

LOG_FILE="../logs/resource.log"
INTERVAL=30  # seconds between checks

echo "=== Resource Monitoring Started at $(date) ===" > $LOG_FILE
echo "Logging to $LOG_FILE every $INTERVAL seconds"

# Create a function to log memory usage
log_memory_usage() {
    echo "=== $(date) ===" >> $LOG_FILE
    
    # Log free memory pages
    vm_stat | grep "Pages free" >> $LOG_FILE
    
    # Log physical memory usage
    top -l 1 -s 0 | grep "PhysMem" >> $LOG_FILE
    
    # Log Metal memory usage if MLX is available
    if python -c "import mlx.core as mx" &> /dev/null; then
        python -c "import mlx.core as mx; print(f'Metal Memory: {mx.metal.get_active_memory()/1e9:.2f} GB')" >> $LOG_FILE
    fi
    
    # Log process memory usage
    echo "Process Memory Usage:" >> $LOG_FILE
    ps -eo pid,rss,command | grep -E "python|whisper" | grep -v grep >> $LOG_FILE
}

# Main monitoring loop
echo "Starting monitoring loop..."
while true; do
    log_memory_usage
    sleep $INTERVAL
done
