#!/bin/bash
# Folder Action Monitoring Script for MeetingMinutesATS
# This script monitors a directory for new audio files and processes them automatically

# Default configuration
PROJECT_DIR="$HOME/Documents/Projects/MeetingMinutesATS"
DEFAULT_WATCH_DIR="$PROJECT_DIR/recordings"
PROCESS_SCRIPT="$PROJECT_DIR/scripts/process.sh"
LOG_FILE="$PROJECT_DIR/logs/folder_monitor.log"
MAX_PROCESSES=2

# Parse command line arguments
WATCH_DIR="$DEFAULT_WATCH_DIR"
while getopts "d:h" opt; do
  case $opt in
    d) WATCH_DIR="$OPTARG" ;;
    h) 
       echo "Usage: $0 [-d directory_to_monitor]"
       echo "  -d  Directory to monitor (default: $DEFAULT_WATCH_DIR)"
       echo "  -h  Show this help message"
       exit 0
       ;;
    \?) 
       echo "Invalid option: -$OPTARG" >&2
       exit 1
       ;;
  esac
done

# Create directories if they don't exist
mkdir -p "$(dirname "$LOG_FILE")"
mkdir -p "$PROJECT_DIR/transcriptions"
mkdir -p "$PROJECT_DIR/recordings"
mkdir -p "$PROJECT_DIR/logs"

# Log function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
    echo "$1"
}

# Check if fswatch is installed
if ! command -v fswatch &> /dev/null; then
    log "Error: fswatch not found. Please install with 'brew install fswatch'"
    exit 1
fi

# Check if the process script exists
if [ ! -f "$PROCESS_SCRIPT" ]; then
    log "Error: Process script not found at $PROCESS_SCRIPT"
    exit 1
fi

# Make sure the process script is executable
chmod +x "$PROCESS_SCRIPT"

# Check if the watch directory exists
if [ ! -d "$WATCH_DIR" ]; then
    log "Creating watch directory: $WATCH_DIR"
    mkdir -p "$WATCH_DIR"
fi

# Function to check if we can start a new process
can_start_process() {
    # Check how many processes are currently running
    RUNNING_PROCESSES=$(pgrep -f "$PROCESS_SCRIPT" | wc -l)
    
    if [ "$RUNNING_PROCESSES" -lt "$MAX_PROCESSES" ]; then
        return 0  # True, can start process
    else
        return 1  # False, cannot start process
    fi
}

# Function to process the queue
process_queue() {
    QUEUE_FILE="$PROJECT_DIR/logs/queue.txt"
    
    # Check if queue file exists and is not empty
    if [ -f "$QUEUE_FILE" ] && [ -s "$QUEUE_FILE" ]; then
        # Get the first file in the queue
        NEXT_FILE=$(head -n 1 "$QUEUE_FILE")
        
        # Remove the first line from the queue
        sed -i '' '1d' "$QUEUE_FILE"
        
        # Process the file
        log "Processing queued file: $NEXT_FILE"
        "$PROCESS_SCRIPT" "$NEXT_FILE" &
        
        # Log the process ID
        log "Started process $! for $NEXT_FILE"
        
        # Notify user
        osascript -e "display notification \"Processing started: $(basename "$NEXT_FILE")\" with title \"MeetingMinutesATS\" subtitle \"From queue\""
    fi
}

# Start monitoring
log "Starting folder monitoring for $WATCH_DIR"
log "Watching for new audio files (m4a, wav, mp3)..."

# Display notification that monitoring has started
osascript -e "display notification \"Monitoring folder: $(basename "$WATCH_DIR")\" with title \"MeetingMinutesATS Folder Monitor\" subtitle \"Watching for audio files\""

# Create a lock file to prevent multiple instances
LOCK_FILE="/tmp/folder_monitor.lock"
if [ -f "$LOCK_FILE" ]; then
    PID=$(cat "$LOCK_FILE")
    if ps -p "$PID" > /dev/null; then
        log "Another instance is already running with PID $PID"
        exit 1
    else
        log "Removing stale lock file"
        rm -f "$LOCK_FILE"
    fi
fi
echo $$ > "$LOCK_FILE"

# Trap to clean up lock file on exit
trap 'rm -f "$LOCK_FILE"; log "Folder monitoring stopped"; exit 0' EXIT INT TERM

# Create queue file if it doesn't exist
touch "$PROJECT_DIR/logs/queue.txt"

# Start the queue processor in the background
(
    while true; do
        sleep 30
        if can_start_process; then
            process_queue
        fi
    done
) &
QUEUE_PROCESSOR_PID=$!

# Trap to kill the queue processor when the main script exits
trap 'kill $QUEUE_PROCESSOR_PID 2>/dev/null; rm -f "$LOCK_FILE"; log "Folder monitoring stopped"; exit 0' EXIT INT TERM

# Start monitoring for new files
fswatch -0 "$WATCH_DIR" | while read -d "" event
do
    # Check if the event is for an audio file
    if [[ "$event" =~ \.(m4a|wav|mp3)$ ]]; then
        log "Detected new audio file: $event"
        
        if can_start_process; then
            # Process the file
            log "Starting processing..."
            "$PROCESS_SCRIPT" "$event" &
            
            # Log the process ID
            log "Started process $! for $event"
            
            # Notify user
            osascript -e "display notification \"Processing started: $(basename "$event")\" with title \"MeetingMinutesATS\""
        else
            log "Maximum number of processes ($MAX_PROCESSES) already running. Queuing file."
            
            # Add to queue
            echo "$event" >> "$PROJECT_DIR/logs/queue.txt"
            
            # Notify user
            osascript -e "display notification \"File queued for processing: $(basename "$event")\" with title \"MeetingMinutesATS\" subtitle \"Queue position: $(wc -l < "$PROJECT_DIR/logs/queue.txt")\""
        fi
    fi
done
