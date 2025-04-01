#!/bin/bash
# Folder Action Monitoring Script for MeetingMinutesATS
# This script monitors a directory for new audio files and processes them automatically

# Configuration
WATCH_DIR="$HOME/Library/Group Containers/group.com.apple.VoiceMemos"
PROCESS_SCRIPT="$HOME/Documents/Projects/MeetingMinutesATS/scripts/process.sh"
LOG_FILE="$HOME/Documents/Projects/MeetingMinutesATS/logs/folder_monitor.log"
SEMAPHORE_FILE="/tmp/whisper_semaphore"
MAX_PROCESSES=2

# Create directories if they don't exist
mkdir -p "$(dirname "$LOG_FILE")"
mkdir -p "$HOME/Documents/Projects/MeetingMinutesATS/transcriptions"

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

# Create the process script if it doesn't exist
if [ ! -f "$PROCESS_SCRIPT" ]; then
    log "Creating process script at $PROCESS_SCRIPT"
    cat > "$PROCESS_SCRIPT" << 'EOF'
#!/bin/bash
# Process script for handling new audio files

# Get the audio file path
AUDIO_FILE="$1"
LOG_FILE="$HOME/Documents/Projects/MeetingMinutesATS/logs/process.log"
TRANSCRIPTIONS_DIR="$HOME/Documents/Projects/MeetingMinutesATS/transcriptions"

# Log function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Check if file exists and is an audio file
if [ ! -f "$AUDIO_FILE" ] || ! file "$AUDIO_FILE" | grep -q "audio"; then
    log "Not a valid audio file: $AUDIO_FILE"
    exit 1
fi

log "Processing new audio file: $AUDIO_FILE"

# Copy the file to our directory
FILENAME=$(basename "$AUDIO_FILE")
COPY_PATH="$HOME/Documents/Projects/MeetingMinutesATS/recordings/$FILENAME"
mkdir -p "$(dirname "$COPY_PATH")"
cp "$AUDIO_FILE" "$COPY_PATH"
log "Copied to $COPY_PATH"

# Activate Python environment
export PATH="$HOME/.pyenv/bin:$PATH"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"
pyenv activate whisper-env

# Run transcription
log "Starting transcription..."
python "$HOME/Documents/Projects/MeetingMinutesATS/src/transcribe.py" "$COPY_PATH"

# Get the output JSON path
BASE_NAME="${FILENAME%.*}"
JSON_PATH="$TRANSCRIPTIONS_DIR/$BASE_NAME.json"

# Run post-processing
log "Starting post-processing..."
python "$HOME/Documents/Projects/MeetingMinutesATS/src/postprocess.py" "$JSON_PATH"

log "Processing complete for $FILENAME"

# Send notification
osascript -e "display notification \"轉錄完成: $BASE_NAME\" with title \"MeetingMinutesATS\" sound name \"Glass\""
EOF

    # Make the process script executable
    chmod +x "$PROCESS_SCRIPT"
fi

# Start monitoring
log "Starting folder monitoring for $WATCH_DIR"
log "Watching for new audio files (m4a, wav, mp3)..."

fswatch -0 "$WATCH_DIR" | while read -d "" event
do
    # Check if the event is for an audio file
    if [[ "$event" =~ \.(m4a|wav|mp3)$ ]]; then
        log "Detected new audio file: $event"
        
        # Check how many processes are currently running
        RUNNING_PROCESSES=$(pgrep -f "$PROCESS_SCRIPT" | wc -l)
        
        if [ "$RUNNING_PROCESSES" -ge "$MAX_PROCESSES" ]; then
            log "Maximum number of processes ($MAX_PROCESSES) already running. Queuing file."
            
            # Add to queue
            echo "$event" >> "$HOME/Documents/Projects/MeetingMinutesATS/logs/queue.txt"
        else
            # Process the file with resource limiting
            log "Starting processing with semaphore..."
            (
                # Try to acquire the semaphore
                flock -n 200 || {
                    log "Could not acquire semaphore, queuing file."
                    echo "$event" >> "$HOME/Documents/Projects/MeetingMinutesATS/logs/queue.txt"
                    exit 1
                }
                
                # Process the file
                "$PROCESS_SCRIPT" "$event" &
                
                # Log the process ID
                log "Started process $! for $event"
            ) 200>"$SEMAPHORE_FILE"
        fi
    fi
done

log "Folder monitoring stopped"
