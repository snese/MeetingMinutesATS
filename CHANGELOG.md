# Changelog

## [1.0.1] - 2025-04-01

### Fixed

#### Raycast Integration
- Fixed AppleScript error "The variable result is not defined. (-2753)" by properly capturing dialog results in variables
- Updated `scripts/raycast_integration.applescript` to use explicit variable assignment for dialog results
- Added Python alternative (`scripts/raycast_integration.py`) for better compatibility
- Made both scripts executable with `chmod +x`
- Updated README.md with clear instructions for both AppleScript and Python options

#### MLX Framework Compatibility
- Fixed Metal device detection in `scripts/setup.sh` for MLX 0.24.1
- Added compatibility code that tries both newer and older MLX APIs
- Added better error handling and reporting for Metal memory operations
- Updated `src/transcribe.py` to handle MLX API differences
- Added debug information to help troubleshoot import issues

#### Dependencies
- Changed requirements.txt to install mlx_whisper directly from GitHub
- Updated MLX version from non-existent 0.0.14 to 0.24.1
- Added detailed error reporting in the transcription script

### Added
- Created test_mlx.py script for debugging MLX imports
- Added memory management compatibility layer for different MLX versions
- Added more robust Python interpreter path detection in scripts

### Documentation
- Updated README.md with detailed Raycast integration instructions
- Added troubleshooting information for MLX installation
- Improved setup instructions for different environments
