# MeetingMinutesATS - Bilingual Meeting Transcription System

MeetingMinutesATS is a specialized transcription system optimized for Apple Silicon M3 Pro (18GB) hardware, using the MLX framework and Whisper large-v3-q4 model. It's specifically designed for transcribing meetings with mixed Chinese and English content, providing accurate transcriptions for bilingual business environments.

## System Requirements

- Apple Silicon Mac (M3 Pro or equivalent)
- macOS Sonoma or newer
- At least 18GB RAM
- At least 10GB available disk space

## Key Features

- **High-Performance Transcription**: 1.5x real-time processing speed (60 minutes of audio ≤ 40 minutes processing time)
- **High Accuracy**: Paragraph-level accuracy ≥ 95% (manually verified)
- **Memory Optimization**: Peak usage ≤ 14GB (preserving 4GB for system)
- **Mixed Language Support**: Optimized for meetings with mixed Traditional Chinese (70%) and English (30%)
- **Bilingual Processing**: Accurately handles code-switching between languages
- **Automation Integration**: Support for Raycast and Folder Action automation

## Directory Structure

```
MeetingMinutesATS/
├── src/                    # Source code
│   ├── transcribe.py       # Core transcription module
│   ├── postprocess.py      # Post-processing pipeline
│   └── quality_validation.py # Quality validation system
├── scripts/                # Scripts
│   ├── setup.sh            # Environment setup script
│   ├── monitor_resources.sh # Resource monitoring script
│   ├── folder_monitor.sh   # Folder monitoring script
│   ├── process.sh          # Processing script
│   ├── maintenance.sh      # Maintenance script
│   └── raycast_integration.applescript # Raycast integration
├── logs/                   # Log files
├── recordings/             # Recording files
├── transcriptions/         # Transcription results
├── config/                 # Configuration files
└── requirements.txt        # Python dependencies
```

## Installation & Setup

### 1. Clone the Repository

```bash
git clone https://github.com/yourusername/MeetingMinutesATS.git
cd MeetingMinutesATS
```

### 2. Run the Setup Script

```bash
chmod +x scripts/setup.sh
./scripts/setup.sh
```

This script will:
- Install system dependencies (pyenv, pyenv-virtualenv, ffmpeg)
- Create a Python 3.10.13 environment
- Install the MLX framework
- Configure Metal acceleration
- Set memory limits

### 3. Download the Model

After the setup script completes, the system will automatically download the Whisper large-v3-q4 model. If you need to download it manually:

```bash
mkdir -p ~/.cache/whisper-large-v3-mlx
wget https://huggingface.co/mlx-community/whisper-large-v3-mlx/resolve/main/weights.npz -P ~/.cache/whisper-large-v3-mlx/
```

## Usage

### Method 1: Using Raycast Integration

#### Option A: Using AppleScript (Recommended)

1. Add a Script Command in Raycast:
   - Open Raycast preferences (⌘+,)
   - Select the "Extensions" tab
   - Select "Script Commands"
   - Click "+" to add a new script
   - Select "AppleScript" as the language
   - Copy the contents of `scripts/raycast_integration.applescript` into the editor
   - Name it "Meeting Recorder" and save

2. Run the script through Raycast to start recording and transcribing

#### Option B: Using Python Script

1. Add a Script Command in Raycast:
   - Open Raycast preferences (⌘+,)
   - Select the "Extensions" tab
   - Select "Script Commands"
   - Click "+" to add a new script
   - Select "Bash" as the language
   - Enter: `python3 $HOME/Documents/Projects/MeetingMinutesATS/scripts/raycast_integration.py`
   - Name it "Meeting Recorder (Python)" and save

2. Run the script through Raycast to start recording and transcribing

#### Option C: Running Scripts Directly

If you encounter issues with Raycast, you can run the scripts directly:

```bash
# AppleScript version
osascript scripts/raycast_integration.applescript

# Python version
python3 scripts/raycast_integration.py
```

### Method 2: Using Folder Monitoring

1. Start the folder monitoring script:

```bash
chmod +x scripts/folder_monitor.sh
./scripts/folder_monitor.sh &
```

By default, the script monitors the `recordings` folder. You can also specify another folder:

```bash
./scripts/folder_monitor.sh -d /path/to/custom/folder
```

2. Place audio files in the monitored folder, and the system will process them automatically

### Method 3: Manual Transcription

1. Activate the Python environment:

```bash
pyenv activate whisper-env
```

2. Run transcription:

```bash
python src/transcribe.py path/to/audio/file.m4a
```

3. Run post-processing:

```bash
python src/postprocess.py transcriptions/file.json --md-only
```

## Transcription Output

The system generates two main output files:

1. **JSON File** (`xxx.json`): Contains complete transcription data, including timestamps and metadata
2. **Markdown File** (`xxx.transcript.md`): Text transcription with timestamp format `[HH:MM:SS - HH:MM:SS]`

The Markdown format is specifically designed for bilingual meetings, preserving both Chinese and English content with accurate timestamps. This makes it easy to review and reference specific parts of the meeting.

## Maintenance & Monitoring

Start the maintenance and monitoring script:

```bash
chmod +x scripts/maintenance.sh
./scripts/maintenance.sh &
```

This script will:
- Monitor system memory usage
- Analyze log files for errors
- Perform memory reclamation when necessary
- Send alerts when problems occur

## Troubleshooting

### Memory Issues

If you encounter out-of-memory errors:

1. Check memory usage in `logs/maintenance.log`
2. Adjust the `MLX_GPU_MEMORY_LIMIT` environment variable (default is 0.75)
3. Use a smaller model (medium-q8 instead of large-v3-q4)
4. Increase audio chunk size (using the `--chunk_size` parameter)

### Transcription Quality Issues

If transcription quality is poor:

1. Adjust the `--beam_size` and `--temperature` parameters
2. Modify the initial prompt to better match the meeting content
3. Ensure good audio quality with reduced background noise

### MLX-Related Issues

If you encounter MLX-related errors:

1. Ensure you have the correct version of MLX installed: `pip install mlx==0.24.1`
2. Install mlx_whisper: `pip install git+https://github.com/mlx-community/mlx-whisper.git`
3. Run a test script to check MLX imports: `python test_mlx.py`
4. Check if the Python environment is correctly activated: `pyenv activate whisper-env`

### AppleScript Errors

If you encounter errors with the Raycast integration script:

1. Try using the Python version of the integration script: `python scripts/raycast_integration.py`
2. Run the AppleScript directly from the command line: `osascript scripts/raycast_integration.applescript`
3. Check if SoX is installed: `brew install sox`

## Version History

See [CHANGELOG.md](CHANGELOG.md) for a detailed record of changes.

## Contributing

Pull Requests and Issues are welcome!

## License

[MIT License](LICENSE)
