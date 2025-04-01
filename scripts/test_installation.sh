#!/bin/bash
# Test Installation Script for MeetingMinutesATS
# This script verifies that the environment is set up correctly

echo "=== MeetingMinutesATS Installation Test ==="
echo "Testing system components..."

# Check for required directories
echo -n "Checking directory structure... "
REQUIRED_DIRS=("src" "scripts" "models" "logs" "recordings" "transcriptions")
MISSING_DIRS=()

for dir in "${REQUIRED_DIRS[@]}"; do
    if [ ! -d "$dir" ]; then
        MISSING_DIRS+=("$dir")
    fi
done

if [ ${#MISSING_DIRS[@]} -eq 0 ]; then
    echo "OK"
else
    echo "FAILED"
    echo "Missing directories: ${MISSING_DIRS[*]}"
    echo "Creating missing directories..."
    for dir in "${MISSING_DIRS[@]}"; do
        mkdir -p "$dir"
        echo "Created $dir"
    done
fi

# Check for required scripts
echo -n "Checking required scripts... "
REQUIRED_SCRIPTS=(
    "scripts/setup.sh"
    "scripts/monitor_resources.sh"
    "scripts/folder_monitor.sh"
    "scripts/process.sh"
    "scripts/maintenance.sh"
    "src/transcribe.py"
    "src/postprocess.py"
    "src/quality_validation.py"
)
MISSING_SCRIPTS=()

for script in "${REQUIRED_SCRIPTS[@]}"; do
    if [ ! -f "$script" ]; then
        MISSING_SCRIPTS+=("$script")
    fi
done

if [ ${#MISSING_SCRIPTS[@]} -eq 0 ]; then
    echo "OK"
else
    echo "FAILED"
    echo "Missing scripts: ${MISSING_SCRIPTS[*]}"
    echo "Please reinstall the system or download the missing files."
    exit 1
fi

# Check for executable permissions
echo -n "Checking executable permissions... "
NON_EXECUTABLE=()

for script in "${REQUIRED_SCRIPTS[@]}"; do
    if [ ! -x "$script" ]; then
        NON_EXECUTABLE+=("$script")
    fi
done

if [ ${#NON_EXECUTABLE[@]} -eq 0 ]; then
    echo "OK"
else
    echo "FAILED"
    echo "The following scripts are not executable: ${NON_EXECUTABLE[*]}"
    echo "Setting executable permissions..."
    chmod +x scripts/*.sh src/*.py
    echo "Permissions set."
fi

# Check for system dependencies
echo -n "Checking system dependencies... "
MISSING_DEPS=()

# Check for Homebrew
if ! command -v brew &> /dev/null; then
    MISSING_DEPS+=("Homebrew")
fi

# Check for pyenv
if ! command -v pyenv &> /dev/null; then
    MISSING_DEPS+=("pyenv")
fi

# Check for ffmpeg
if ! command -v ffmpeg &> /dev/null; then
    MISSING_DEPS+=("ffmpeg")
fi

if [ ${#MISSING_DEPS[@]} -eq 0 ]; then
    echo "OK"
else
    echo "FAILED"
    echo "Missing dependencies: ${MISSING_DEPS[*]}"
    echo "Please run scripts/setup.sh to install the required dependencies."
fi

# Check for Python environment
echo -n "Checking Python environment... "
if pyenv versions | grep -q "whisper-env"; then
    echo "OK"
else
    echo "FAILED"
    echo "Python environment 'whisper-env' not found."
    echo "Please run scripts/setup.sh to set up the Python environment."
fi

# Check for MLX installation
echo -n "Checking MLX installation... "
if pyenv activate whisper-env &> /dev/null && python -c "import mlx" &> /dev/null; then
    echo "OK"
else
    echo "FAILED"
    echo "MLX framework not installed or not working."
    echo "Please run scripts/setup.sh to install the MLX framework."
fi

# Check for model files
echo -n "Checking model files... "
MODEL_PATH="$HOME/models/whisper-large-v3-mlx/weights.npz"
if [ -f "$MODEL_PATH" ]; then
    echo "OK"
else
    echo "NOT FOUND"
    echo "Model file not found at $MODEL_PATH"
    echo "The model will be downloaded automatically when running the transcription for the first time."
    echo "Alternatively, you can download it manually:"
    echo "mkdir -p ~/models/whisper-large-v3-mlx"
    echo "wget https://huggingface.co/mlx-community/whisper-large-v3-mlx/resolve/main/weights.npz -P ~/models/whisper-large-v3-mlx/"
fi

# Create a test audio file if it doesn't exist
TEST_AUDIO="test_audio.wav"
if [ ! -f "$TEST_AUDIO" ]; then
    echo "Creating a test audio file..."
    if command -v ffmpeg &> /dev/null; then
        # Generate a 3-second test tone
        ffmpeg -f lavfi -i "sine=frequency=440:duration=3" -c:a pcm_s16le -ar 16000 -ac 1 "$TEST_AUDIO" -y &> /dev/null
        echo "Created test audio file: $TEST_AUDIO"
    else
        echo "Cannot create test audio file: ffmpeg not installed."
    fi
fi

# Test transcription if the audio file exists
if [ -f "$TEST_AUDIO" ] && pyenv versions | grep -q "whisper-env"; then
    echo "Testing transcription with a short audio file..."
    echo "This may take a moment..."
    
    # Activate the Python environment
    export PATH="$HOME/.pyenv/bin:$PATH"
    eval "$(pyenv init -)"
    eval "$(pyenv virtualenv-init -)"
    pyenv activate whisper-env
    
    # Set memory limits
    export MLX_GPU_MEMORY_LIMIT=0.75
    export DYLD_LIBRARY_PATH=/opt/homebrew/lib
    
    # Run transcription with minimal output
    python src/transcribe.py "$TEST_AUDIO" &> /dev/null
    
    # Check if the output file was created
    BASE_NAME="${TEST_AUDIO%.*}"
    JSON_PATH="transcriptions/$BASE_NAME.json"
    
    if [ -f "$JSON_PATH" ]; then
        echo "✅ Transcription test successful!"
        echo "Output file created: $JSON_PATH"
    else
        echo "❌ Transcription test failed."
        echo "Output file not created."
    fi
fi

echo "=== Installation Test Complete ==="
echo "If all checks passed, the system is ready to use."
echo "If any checks failed, please follow the instructions above to resolve the issues."
echo "For more information, see the README.md file."
