#!/bin/bash
# Process script for handling new audio files

# Get the audio file path
AUDIO_FILE="$1"
PROJECT_DIR="$HOME/Documents/Projects/MeetingMinutesATS"
LOG_FILE="$PROJECT_DIR/logs/process.log"
TRANSCRIPTIONS_DIR="$PROJECT_DIR/transcriptions"

# Create log directory if it doesn't exist
mkdir -p "$(dirname "$LOG_FILE")"

# Log function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
    echo "$1"
}

# Check if file exists
if [ ! -f "$AUDIO_FILE" ]; then
    log "File does not exist: $AUDIO_FILE"
    exit 1
fi

# Check file extension instead of using 'file' command
FILE_EXT="${AUDIO_FILE##*.}"
if [[ ! "$FILE_EXT" =~ ^(m4a|wav|mp3)$ ]]; then
    log "Not a supported audio file extension: $FILE_EXT"
    exit 1
fi

log "Processing new audio file: $AUDIO_FILE"

# Copy the file to our directory (only if it's not already there)
FILENAME=$(basename "$AUDIO_FILE")
COPY_PATH="$PROJECT_DIR/recordings/$FILENAME"

# Only copy if the file is not already in our recordings directory
if [[ "$AUDIO_FILE" != "$COPY_PATH" ]]; then
    mkdir -p "$(dirname "$COPY_PATH")"
    cp "$AUDIO_FILE" "$COPY_PATH"
    log "Copied to $COPY_PATH"
else
    log "File is already in recordings directory, no need to copy"
fi

# Activate Python environment
export PATH="$HOME/.pyenv/bin:$PATH"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"
pyenv activate whisper-env

# Run transcription
log "Starting transcription..."
python "$PROJECT_DIR/src/transcribe.py" "$COPY_PATH"

# Get the output JSON path
BASE_NAME="${FILENAME%.*}"
JSON_PATH="$TRANSCRIPTIONS_DIR/$BASE_NAME.json"

# Run post-processing to generate Markdown transcript
log "Generating Markdown transcript..."
python "$PROJECT_DIR/src/postprocess.py" "$JSON_PATH" --md-only

# Clean up any temporary files
rm -f "$TRANSCRIPTIONS_DIR/$BASE_NAME.json.temp"
rm -f "$TRANSCRIPTIONS_DIR/$BASE_NAME.processed.json"
rm -f "$TRANSCRIPTIONS_DIR/$BASE_NAME.processed.txt"
rm -f "$TRANSCRIPTIONS_DIR/$BASE_NAME.transcript.srt"

log "Processing complete for $FILENAME"

# Send notification
osascript -e "display notification \"轉錄完成: $BASE_NAME\" with title \"MeetingMinutesATS\" sound name \"Glass\""
