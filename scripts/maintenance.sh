#!/bin/bash
# Maintenance and Monitoring Script for MeetingMinutesATS
# Implements memory reclamation, log analysis, and error handling

# Configuration
LOG_DIR="$HOME/Documents/Projects/MeetingMinutesATS/logs"
MAIN_LOG="$LOG_DIR/maintenance.log"
WHISPER_LOG="$LOG_DIR/whisper.log"
ALERT_SCRIPT="$HOME/Documents/Projects/MeetingMinutesATS/scripts/send_alert.sh"
MEMORY_THRESHOLD=14  # GB
CONSECUTIVE_THRESHOLD=3
ERROR_PATTERNS=(
    "OutOfMemoryError"
    "CudaError"
    "Metal buffer allocation failed"
    "RuntimeError"
    "MemoryError"
)

# Create directories if they don't exist
mkdir -p "$LOG_DIR"

# Log function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$MAIN_LOG"
    echo "$1"
}

# Alert function
send_alert() {
    local message="$1"
    local level="${2:-warning}"  # default to warning level
    
    log "ALERT [$level]: $message"
    
    # Create alert script if it doesn't exist
    if [ ! -f "$ALERT_SCRIPT" ]; then
        cat > "$ALERT_SCRIPT" << 'EOF'
#!/bin/bash
# Alert script for MeetingMinutesATS
# Sends notifications for system alerts

MESSAGE="$1"
LEVEL="$2"

# Send notification
osascript -e "display notification \"$MESSAGE\" with title \"MeetingMinutesATS Alert: $LEVEL\" sound name \"Basso\""

# Log to system log
logger -t "MeetingMinutesATS" "$LEVEL: $MESSAGE"

# You can add more alert methods here, such as:
# - Email notifications
# - Slack/Teams messages
# - SMS alerts
EOF
        chmod +x "$ALERT_SCRIPT"
    fi
    
    # Send the alert
    "$ALERT_SCRIPT" "$message" "$level"
}

# Memory check function
check_memory() {
    # Get current memory usage in GB
    local mem_usage=$(vm_stat | grep "Pages active" | awk '{print $3}' | sed 's/\.//')
    local page_size=$(vm_stat | grep "page size of" | awk '{print $8}')
    local mem_gb=$(echo "scale=2; $mem_usage * $page_size / 1024 / 1024 / 1024" | bc)
    
    log "Current memory usage: ${mem_gb}GB"
    
    # Check if memory usage exceeds threshold
    if (( $(echo "$mem_gb > $MEMORY_THRESHOLD" | bc -l) )); then
        log "WARNING: Memory usage exceeds threshold (${mem_gb}GB > ${MEMORY_THRESHOLD}GB)"
        return 1
    fi
    
    return 0
}

# Metal memory check function
check_metal_memory() {
    # Get Metal memory usage using Python and MLX
    local metal_mem=$(python -c "
import mlx.core as mx
try:
    mem = mx.metal.get_active_memory() / 1e9
    print(f'{mem:.2f}')
except Exception as e:
    print('ERROR')
" 2>/dev/null)

    # Check if we got a valid result
    if [[ "$metal_mem" == "ERROR" ]]; then
        log "Could not get Metal memory usage"
        return 0
    fi
    
    log "Current Metal memory usage: ${metal_mem}GB"
    
    # Check if Metal memory usage exceeds threshold
    if (( $(echo "$metal_mem > $MEMORY_THRESHOLD" | bc -l) )); then
        log "WARNING: Metal memory usage exceeds threshold (${metal_mem}GB > ${MEMORY_THRESHOLD}GB)"
        return 1
    fi
    
    return 0
}

# Log analysis function
analyze_logs() {
    log "Analyzing logs for errors..."
    
    # Check for error patterns in the whisper log
    for pattern in "${ERROR_PATTERNS[@]}"; do
        if grep -q "$pattern" "$WHISPER_LOG" 2>/dev/null; then
            local error_line=$(grep -m 1 "$pattern" "$WHISPER_LOG")
            send_alert "Error detected: $error_line" "error"
            
            # Take action based on error type
            if [[ "$error_line" == *"OutOfMemoryError"* ]] || [[ "$error_line" == *"Metal buffer allocation failed"* ]]; then
                log "Memory-related error detected, triggering emergency memory reclamation"
                reclaim_memory "emergency"
                
                # Downgrade model if necessary
                adjust_parameters
            fi
        fi
    done
}

# Memory reclamation function
reclaim_memory() {
    local mode="${1:-normal}"  # normal or emergency
    
    log "Reclaiming memory (mode: $mode)..."
    
    # Run Python garbage collection
    python -c "
import gc
import mlx.core as mx

print(f'Before GC: {mx.metal.get_active_memory()/1e9:.2f}GB')
mx.gc()
print(f'After GC: {mx.metal.get_active_memory()/1e9:.2f}GB')

if '$mode' == 'emergency':
    print('Emergency mode: clearing Metal cache')
    mx.metal.clear_cache()
    print(f'After cache clear: {mx.metal.get_active_memory()/1e9:.2f}GB')
" 2>/dev/null

    # Kill any stuck processes if in emergency mode
    if [[ "$mode" == "emergency" ]]; then
        log "Emergency mode: checking for stuck processes"
        
        # Find processes using excessive memory
        local high_mem_pids=$(ps -eo pid,%mem,command | awk '$2 > 80.0 && $3 ~ /python/ {print $1}')
        
        if [[ -n "$high_mem_pids" ]]; then
            log "Found processes using excessive memory: $high_mem_pids"
            
            # Kill the processes
            for pid in $high_mem_pids; do
                log "Killing process $pid"
                kill -15 "$pid"  # Try graceful termination first
                sleep 2
                kill -9 "$pid" 2>/dev/null  # Force kill if still running
            done
        fi
    fi
}

# Parameter adjustment function
adjust_parameters() {
    log "Adjusting parameters due to memory issues..."
    
    # Create a config file for reduced parameters if it doesn't exist
    local config_file="$HOME/Documents/Projects/MeetingMinutesATS/config/reduced_params.json"
    mkdir -p "$(dirname "$config_file")"
    
    if [ ! -f "$config_file" ]; then
        cat > "$config_file" << EOF
{
    "model": "medium-q8",
    "beam_size": 3,
    "chunk_size": 180,
    "memory_limit": 0.6
}
EOF
    fi
    
    # Update environment variable for memory limit
    echo 'export MLX_GPU_MEMORY_LIMIT=0.6' >> ~/.zshrc
    export MLX_GPU_MEMORY_LIMIT=0.6
    
    send_alert "Parameters adjusted to reduce memory usage. Using medium-q8 model." "warning"
}

# Error detection and recovery function
monitor_errors() {
    log "Starting error monitoring..."
    
    # Monitor the whisper log for errors
    if [ -f "$WHISPER_LOG" ]; then
        tail -f "$WHISPER_LOG" | grep --line-buffered -E "$(IFS="|"; echo "${ERROR_PATTERNS[*]}")" | while read -r line; do
            send_alert "Error detected: $line" "error"
            
            # Take action based on error type
            if [[ "$line" == *"OutOfMemoryError"* ]] || [[ "$line" == *"Metal buffer allocation failed"* ]]; then
                log "Memory-related error detected, triggering emergency memory reclamation"
                reclaim_memory "emergency"
                
                # Downgrade model if necessary
                adjust_parameters
            fi
        done &
    else
        log "Whisper log file not found at $WHISPER_LOG"
    fi
}

# Main maintenance loop
main() {
    log "Starting maintenance and monitoring script"
    
    # Start error monitoring in the background
    monitor_errors
    
    # Initialize consecutive memory threshold counter
    local consecutive_high_mem=0
    
    # Main loop
    while true; do
        # Check system memory
        if ! check_memory; then
            consecutive_high_mem=$((consecutive_high_mem + 1))
        else
            consecutive_high_mem=0
        fi
        
        # Check Metal memory
        if ! check_metal_memory; then
            consecutive_high_mem=$((consecutive_high_mem + 1))
        fi
        
        # Take action if memory usage is consistently high
        if [ "$consecutive_high_mem" -ge "$CONSECUTIVE_THRESHOLD" ]; then
            send_alert "Memory usage exceeded threshold for $CONSECUTIVE_THRESHOLD consecutive checks" "critical"
            reclaim_memory "emergency"
            adjust_parameters
            consecutive_high_mem=0
        fi
        
        # Analyze logs for errors
        analyze_logs
        
        # Sleep before next check
        sleep 300  # Check every 5 minutes
    done
}

# Run the main function
main
