#!/bin/bash
# MeetingMinutesATS Launcher Script
# Provides a unified interface for the transcription system

# Get the directory of this script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# Configuration
CONFIG_FILE="config/default_config.json"
PYTHON_ENV="whisper-env"

# Function to show help
show_help() {
    echo "MeetingMinutesATS - 會議轉錄系統"
    echo ""
    echo "Usage: ./meetingminutesats.sh [command] [options]"
    echo ""
    echo "Commands:"
    echo "  setup           Install dependencies and set up the environment"
    echo "  transcribe      Transcribe an audio file"
    echo "  monitor         Start folder monitoring for automatic transcription"
    echo "  raycast         Launch Raycast integration"
    echo "  test            Run the installation test"
    echo "  test-all        Run all automated tests"
    echo "  config          Manage configuration settings"
    echo "  validate        Run quality validation tests"
    echo "  maintenance     Start the maintenance and monitoring system"
    echo "  help            Show this help message"
    echo ""
    echo "Examples:"
    echo "  ./meetingminutesats.sh setup"
    echo "  ./meetingminutesats.sh transcribe recordings/meeting.m4a"
    echo "  ./meetingminutesats.sh monitor"
    echo "  ./meetingminutesats.sh config --show"
    echo ""
    echo "For more information, see the README.md file."
}

# Function to activate Python environment
activate_env() {
    export PATH="$HOME/.pyenv/bin:$PATH"
    eval "$(pyenv init -)"
    eval "$(pyenv virtualenv-init -)"
    pyenv activate $PYTHON_ENV 2>/dev/null || {
        echo "Python environment '$PYTHON_ENV' not found."
        echo "Please run './meetingminutesats.sh setup' first."
        exit 1
    }
    
    # Set environment variables
    export MLX_GPU_MEMORY_LIMIT=0.75
    export DYLD_LIBRARY_PATH=/opt/homebrew/lib
}

# Check if a command was provided
if [ $# -eq 0 ]; then
    show_help
    exit 0
fi

# Process commands
case "$1" in
    setup)
        echo "Setting up MeetingMinutesATS..."
        chmod +x scripts/setup.sh
        ./scripts/setup.sh
        ;;
        
    transcribe)
        if [ $# -lt 2 ]; then
            echo "Error: No audio file specified."
            echo "Usage: ./meetingminutesats.sh transcribe [audio_file]"
            exit 1
        fi
        
        AUDIO_FILE="$2"
        shift 2
        
        # Check if file exists
        if [ ! -f "$AUDIO_FILE" ]; then
            echo "Error: Audio file not found: $AUDIO_FILE"
            exit 1
        fi
        
        echo "Transcribing $AUDIO_FILE..."
        activate_env
        python src/transcribe.py "$AUDIO_FILE" "$@"
        
        # Get the output JSON path
        BASE_NAME=$(basename "${AUDIO_FILE%.*}")
        JSON_PATH="transcriptions/$BASE_NAME.json"
        
        # Run post-processing if transcription was successful
        if [ -f "$JSON_PATH" ]; then
            echo "Running post-processing..."
            python src/postprocess.py "$JSON_PATH"
            
            # Show the result
            TEXT_PATH="${JSON_PATH%.json}.processed.txt"
            if [ -f "$TEXT_PATH" ]; then
                echo "Transcription complete. Result saved to $TEXT_PATH"
                echo "Opening result..."
                open "$TEXT_PATH"
            fi
        fi
        ;;
        
    monitor)
        echo "Starting folder monitoring..."
        chmod +x scripts/folder_monitor.sh
        ./scripts/folder_monitor.sh
        ;;
        
    raycast)
        echo "Launching Raycast integration..."
        osascript scripts/raycast_integration.applescript
        ;;
        
    test)
        echo "Running installation test..."
        chmod +x scripts/test_installation.sh
        ./scripts/test_installation.sh
        ;;
        
    test-all)
        echo "Running all automated tests..."
        chmod +x scripts/run_all_tests.sh
        ./scripts/run_all_tests.sh
        ;;
        
    config)
        shift
        activate_env
        python src/config_manager.py "$@"
        ;;
        
    validate)
        echo "Running quality validation tests..."
        activate_env
        python src/quality_validation.py "$@"
        ;;
        
    maintenance)
        echo "Starting maintenance and monitoring system..."
        chmod +x scripts/maintenance.sh
        ./scripts/maintenance.sh
        ;;
        
    help)
        show_help
        ;;
        
    *)
        echo "Unknown command: $1"
        show_help
        exit 1
        ;;
esac

exit 0
