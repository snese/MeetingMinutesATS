# MeetingMinutesATS Test Plan

This document outlines a step-by-step test plan for verifying the functionality of the MeetingMinutesATS system. Each test case focuses on a specific component or feature of the system.

## Prerequisites

Before starting the tests, ensure that:
- You are using a Mac with Apple Silicon (M3 Pro or equivalent)
- You have at least 18GB of RAM
- You have at least 10GB of free disk space
- You have an internet connection (for downloading the model)

## Test Cases

### Test Case 1: Environment Setup

**Objective**: Verify that the environment setup script installs all required dependencies correctly.

**Steps**:
1. Run the setup script:
   ```bash
   ./meetingminutesats.sh setup
   ```
2. Verify that the following components are installed:
   - Homebrew
   - pyenv and pyenv-virtualenv
   - ffmpeg
   - Python 3.10.13 environment named "whisper-env"
   - MLX framework

**Expected Result**: All components are installed successfully without errors.

### Test Case 2: Installation Test

**Objective**: Verify that the installation test script correctly identifies the system components.

**Steps**:
1. Run the installation test script:
   ```bash
   ./meetingminutesats.sh test
   ```

**Expected Result**: The test script should report that all required components are present and working.

### Test Case 3: Basic Transcription

**Objective**: Verify that the system can transcribe a simple audio file.

**Steps**:
1. Use the test audio file or create a new one:
   ```bash
   # Optional: Create a test audio file if needed
   ffmpeg -f lavfi -i "sine=frequency=440:duration=3" -c:a pcm_s16le -ar 16000 -ac 1 test_audio.wav -y
   ```
2. Run the transcription:
   ```bash
   ./meetingminutesats.sh transcribe test_audio.wav
   ```

**Expected Result**: The system should process the audio file and generate a transcription in the `transcriptions` directory.

### Test Case 4: Configuration Management

**Objective**: Verify that the configuration manager can display and modify settings.

**Steps**:
1. Show the current configuration:
   ```bash
   ./meetingminutesats.sh config --show
   ```
2. Modify a configuration setting:
   ```bash
   ./meetingminutesats.sh config --set transcription chunk_size 180
   ```
3. Verify the change:
   ```bash
   ./meetingminutesats.sh config --get transcription chunk_size
   ```
4. Reset to defaults:
   ```bash
   ./meetingminutesats.sh config --reset
   ```

**Expected Result**: The configuration should be displayed, modified, and reset successfully.

### Test Case 5: Resource Monitoring

**Objective**: Verify that the resource monitoring script can track system resources.

**Steps**:
1. Run the resource monitoring script:
   ```bash
   ./scripts/monitor_resources.sh
   ```
2. Let it run for a minute to collect data.
3. Press Ctrl+C to stop the script.
4. Check the log file:
   ```bash
   cat logs/resource.log
   ```

**Expected Result**: The log file should contain entries with memory usage information.

### Test Case 6: Quality Validation

**Objective**: Verify that the quality validation system can evaluate transcription quality.

**Steps**:
1. Run the quality validation test:
   ```bash
   ./meetingminutesats.sh validate --test pure_chinese
   ```

**Expected Result**: The system should generate test cases and evaluate the transcription quality.

### Test Case 7: Folder Monitoring (Background Mode)

**Objective**: Verify that the folder monitoring script can detect and process new audio files.

**Steps**:
1. Start the folder monitoring script in the background:
   ```bash
   ./meetingminutesats.sh monitor &
   ```
2. Copy an audio file to the monitored directory:
   ```bash
   cp test_audio.wav ~/Library/Group\ Containers/group.com.apple.VoiceMemos/
   ```
3. Wait for the system to process the file.
4. Check the logs:
   ```bash
   cat logs/folder_monitor.log
   ```
5. Stop the background process:
   ```bash
   pkill -f folder_monitor.sh
   ```

**Expected Result**: The system should detect the new file, process it, and generate a transcription.

### Test Case 8: Maintenance Script

**Objective**: Verify that the maintenance script can monitor and manage system resources.

**Steps**:
1. Run the maintenance script in the background:
   ```bash
   ./meetingminutesats.sh maintenance &
   ```
2. Let it run for a minute to initialize.
3. Check the log file:
   ```bash
   cat logs/maintenance.log
   ```
4. Stop the background process:
   ```bash
   pkill -f maintenance.sh
   ```

**Expected Result**: The maintenance script should start successfully and log system status information.

### Test Case 9: Raycast Integration

**Objective**: Verify that the Raycast integration script works correctly.

**Steps**:
1. Run the Raycast integration script:
   ```bash
   ./meetingminutesats.sh raycast
   ```
2. Follow the on-screen prompts to record a short audio clip.
3. Choose to transcribe the recording when prompted.

**Expected Result**: The script should record audio, save it, and offer to transcribe it.

### Test Case 10: End-to-End Test with Real Audio

**Objective**: Verify that the system can transcribe a real meeting recording with mixed Chinese and English content.

**Steps**:
1. Prepare a short meeting recording with mixed Chinese and English content.
2. Run the transcription:
   ```bash
   ./meetingminutesats.sh transcribe path/to/meeting/recording.m4a
   ```
3. Examine the transcription result:
   ```bash
   cat transcriptions/recording.processed.txt
   ```

**Expected Result**: The system should accurately transcribe the meeting content, correctly handling both Chinese and English speech.

## Test Results Summary

| Test Case | Description | Status | Notes |
|-----------|-------------|--------|-------|
| 1 | Environment Setup | | |
| 2 | Installation Test | | |
| 3 | Basic Transcription | | |
| 4 | Configuration Management | | |
| 5 | Resource Monitoring | | |
| 6 | Quality Validation | | |
| 7 | Folder Monitoring | | |
| 8 | Maintenance Script | | |
| 9 | Raycast Integration | | |
| 10 | End-to-End Test | | |

Fill in the "Status" column with "Pass" or "Fail" as you complete each test. Add any relevant notes or observations in the "Notes" column.
