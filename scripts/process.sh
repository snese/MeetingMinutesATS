#!/bin/bash
# Process script for handling new audio files
# This script is called by folder_monitor.sh when a new audio file is detected

# Get the audio file path
AUDIO_FILE="$1"
LOG_FILE="$HOME/Documents/Projects/MeetingMinutesATS/logs/process.log"
TRANSCRIPTIONS_DIR="$HOME/Documents/Projects/MeetingMinutesATS/transcriptions"
RECORDINGS_DIR="$HOME/Documents/Projects/MeetingMinutesATS/recordings"

# Create directories if they don't exist
mkdir -p "$(dirname "$LOG_FILE")"
mkdir -p "$TRANSCRIPTIONS_DIR"
mkdir -p "$RECORDINGS_DIR"

# Log function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
    echo "$1"
}

# Check if file exists and is an audio file
if [ ! -f "$AUDIO_FILE" ]; then
    log "File not found: $AUDIO_FILE"
    exit 1
fi

# Check if it's an audio file using file command
if ! file "$AUDIO_FILE" | grep -q "audio"; then
    log "Not a valid audio file: $AUDIO_FILE"
    exit 1
fi

log "Processing new audio file: $AUDIO_FILE"

# Copy the file to our recordings directory
FILENAME=$(basename "$AUDIO_FILE")
COPY_PATH="$RECORDINGS_DIR/$FILENAME"
cp "$AUDIO_FILE" "$COPY_PATH"
log "Copied to $COPY_PATH"

# Activate Python environment
export PATH="$HOME/.pyenv/bin:$PATH"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"
pyenv activate whisper-env

# Set memory limits
export MLX_GPU_MEMORY_LIMIT=0.75
export DYLD_LIBRARY_PATH=/opt/homebrew/lib

# Run transcription
log "Starting transcription..."
python "$HOME/Documents/Projects/MeetingMinutesATS/src/transcribe.py" "$COPY_PATH"

# Get the output JSON path
BASE_NAME="${FILENAME%.*}"
JSON_PATH="$TRANSCRIPTIONS_DIR/$BASE_NAME.json"

# Check if transcription was successful
if [ ! -f "$JSON_PATH" ]; then
    log "Transcription failed: Output file not found at $JSON_PATH"
    
    # Send failure notification
    osascript -e "display notification \"轉錄失敗: $BASE_NAME\" with title \"MeetingMinutesATS\" sound name \"Basso\""
    exit 1
fi

# Run post-processing
log "Starting post-processing..."
python "$HOME/Documents/Projects/MeetingMinutesATS/src/postprocess.py" "$JSON_PATH"

# Check if post-processing was successful
PROCESSED_PATH="${JSON_PATH%.json}.processed.txt"
if [ ! -f "$PROCESSED_PATH" ]; then
    log "Post-processing failed: Output file not found at $PROCESSED_PATH"
    
    # Send failure notification
    osascript -e "display notification \"後處理失敗: $BASE_NAME\" with title \"MeetingMinutesATS\" sound name \"Basso\""
    exit 1
fi

log "Processing complete for $FILENAME"
log "Transcription saved to $PROCESSED_PATH"

# Send success notification
osascript -e "display notification \"轉錄完成: $BASE_NAME\" with title \"MeetingMinutesATS\" sound name \"Glass\""

# Check if there are queued files to process
QUEUE_FILE="$HOME/Documents/Projects/MeetingMinutesATS/logs/queue.txt"
if [ -f "$QUEUE_FILE" ] && [ -s "$QUEUE_FILE" ]; then
    # Get the next file from the queue
    NEXT_FILE=$(head -n 1 "$QUEUE_FILE")
    
    # Remove the first line from the queue
    sed -i '' '1d' "$QUEUE_FILE"
    
    # Process the next file if it exists
    if [ -n "$NEXT_FILE" ] && [ -f "$NEXT_FILE" ]; then
        log "Processing next file from queue: $NEXT_FILE"
        "$0" "$NEXT_FILE" &
        log "Started process $! for queued file"
    fi
fi

exit 0
