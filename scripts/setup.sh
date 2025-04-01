#!/bin/bash
# MeetingMinutesATS Setup Script
# This script installs all required dependencies and configures the environment

echo "=== MeetingMinutesATS Setup ==="
echo "Installing system dependencies..."

# Check if Homebrew is installed
if ! command -v brew &> /dev/null; then
    echo "Homebrew not found. Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Install system dependencies
echo "Installing pyenv, pyenv-virtualenv, ffmpeg, and sox..."
brew install pyenv pyenv-virtualenv ffmpeg sox

# Verify ffmpeg installation
if [ -f "/opt/homebrew/bin/ffmpeg" ]; then
    echo "✅ FFmpeg installed successfully"
else
    echo "❌ FFmpeg installation failed"
    exit 1
fi

# Verify sox installation
if [ -f "/opt/homebrew/bin/sox" ]; then
    echo "✅ SoX installed successfully"
else
    echo "❌ SoX installation failed"
    exit 1
fi

# Configure pyenv
echo "Configuring pyenv..."
echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.zshrc
echo 'command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.zshrc
echo 'eval "$(pyenv init -)"' >> ~/.zshrc
echo 'eval "$(pyenv virtualenv-init -)"' >> ~/.zshrc

# Load pyenv in current shell
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"

# Install Python 3.10.13
echo "Installing Python 3.10.13..."
pyenv install 3.10.13

# Create virtual environment
echo "Creating whisper-env virtual environment..."
pyenv virtualenv 3.10.13 whisper-env

# Activate environment
echo "Activating whisper-env..."
pyenv local whisper-env

# Install Python dependencies
echo "Installing Python dependencies..."
pip install -r requirements.txt

# Verify MLX installation
python -c "import mlx; print('✅ MLX installed successfully')" || { echo "❌ MLX installation failed"; exit 1; }

# Install additional dependencies if needed
echo "Checking for additional dependencies..."
python -c "import soundfile, sounddevice, jiwer" 2>/dev/null || {
    echo "Installing additional audio and evaluation packages..."
    pip install soundfile sounddevice jiwer
}

# Configure Metal acceleration
echo "Configuring Metal acceleration..."
echo 'export DYLD_LIBRARY_PATH=/opt/homebrew/lib' >> ~/.zshrc
export DYLD_LIBRARY_PATH=/opt/homebrew/lib

# Set memory limits
echo "Setting memory limits..."
echo 'export MLX_GPU_MEMORY_LIMIT=0.75' >> ~/.zshrc
export MLX_GPU_MEMORY_LIMIT=0.75

# Verify Metal version
echo "Checking Metal device..."
python -c "
import mlx.core as mx
try:
    # Try newer API (0.24.1+)
    devices = mx.devices()
    if devices:
        print(f'Metal device: {devices[0]}')
    else:
        print('No Metal devices found')
except Exception as e:
    try:
        # Try older API
        device = mx.metal.get_device()
        print(f'Metal device: {device.name}')
    except Exception as e2:
        print(f'Could not detect Metal device: {e2}')
"

echo "=== Setup Complete ==="
echo "Please restart your terminal or run 'source ~/.zshrc' to apply changes"
echo "To activate the environment manually: pyenv activate whisper-env"
