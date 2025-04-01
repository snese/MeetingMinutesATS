# MeetingMinutesATS Testing Guide

This guide provides instructions for testing the MeetingMinutesATS system. It outlines the testing process, available tools, and how to interpret the results.

## Testing Overview

The MeetingMinutesATS system includes a comprehensive testing framework to verify that all components are working correctly. The testing framework consists of:

1. **Individual Test Scripts**: Scripts for testing specific components of the system.
2. **Automated Test Suite**: A script that runs all automated tests in sequence.
3. **Test Plan**: A detailed plan outlining all test cases and expected results.
4. **Test Checklist**: A checklist for tracking test progress and results.

## Testing Tools

The following tools are available for testing the system:

### 1. Installation Test

Tests that all required components are installed correctly.

```bash
./meetingminutesats.sh test
```

### 2. All Automated Tests

Runs all automated tests in sequence.

```bash
./meetingminutesats.sh test-all
```

### 3. Individual Component Tests

Test specific components of the system:

- **Transcription**: `./meetingminutesats.sh transcribe test_audio.wav`
- **Configuration**: `./meetingminutesats.sh config --show`
- **Quality Validation**: `./meetingminutesats.sh validate --test pure_chinese`
- **Resource Monitoring**: `./scripts/monitor_resources.sh`
- **Folder Monitoring**: `./meetingminutesats.sh monitor`
- **Maintenance**: `./meetingminutesats.sh maintenance`
- **Raycast Integration**: `./meetingminutesats.sh raycast`

## Testing Process

### Step 1: Prepare the Environment

Before starting the tests, ensure that:
- You are using a Mac with Apple Silicon (M3 Pro or equivalent)
- You have at least 18GB of RAM
- You have at least 10GB of free disk space
- You have an internet connection (for downloading the model)

### Step 2: Run the Setup Script

Run the setup script to install all required dependencies:

```bash
./meetingminutesats.sh setup
```

This will install:
- Homebrew (if not already installed)
- pyenv and pyenv-virtualenv
- ffmpeg
- Python 3.10.13 environment named "whisper-env"
- MLX framework and other dependencies

### Step 3: Run the Installation Test

Run the installation test to verify that all components are installed correctly:

```bash
./meetingminutesats.sh test
```

This will check:
- Required directories exist
- Required scripts exist and are executable
- System dependencies are installed
- Python environment is set up correctly
- MLX framework is installed
- Model files are available or can be downloaded

### Step 4: Run the Automated Tests

Run the automated test suite to verify that all components are working correctly:

```bash
./meetingminutesats.sh test-all
```

This will run all automated tests in sequence and provide a summary of the results.

### Step 5: Complete the Manual Tests

Some tests require manual verification. Use the test checklist to track your progress:

1. Open the test checklist: `test_checklist.md`
2. Follow the instructions for each test
3. Check off each item as you complete it
4. Note any issues or observations

### Step 6: End-to-End Test

Perform an end-to-end test with a real meeting recording:

1. Prepare a short meeting recording with mixed Chinese and English content
2. Run the transcription: `./meetingminutesats.sh transcribe path/to/meeting/recording.m4a`
3. Examine the transcription result: `cat transcriptions/recording.processed.txt`
4. Verify that the transcription is accurate and meets the requirements

## Interpreting Test Results

### Automated Test Results

The automated test suite will provide a summary of the results for each test. The results will be one of:

- **PASS**: The test passed successfully
- **FAIL**: The test failed

For failed tests, check the log file for more information:

```bash
cat test_results/test_run_YYYYMMDD_HHMMSS.log
```

### Manual Test Results

For manual tests, use the test checklist to track your progress and results. Note any issues or observations in the "Notes and Observations" section.

## Troubleshooting

If you encounter issues during testing, try the following:

1. Check the log files for error messages:
   - `logs/resource.log`: Resource monitoring log
   - `logs/maintenance.log`: Maintenance log
   - `logs/folder_monitor.log`: Folder monitoring log
   - `logs/process.log`: Process log
   - `test_results/test_run_YYYYMMDD_HHMMSS.log`: Test run log

2. Verify that all required components are installed correctly:
   ```bash
   ./meetingminutesats.sh test
   ```

3. Check the system requirements:
   - Mac with Apple Silicon (M3 Pro or equivalent)
   - At least 18GB of RAM
   - At least 10GB of free disk space
   - Internet connection (for downloading the model)

4. Try resetting the configuration to defaults:
   ```bash
   ./meetingminutesats.sh config --reset
   ```

5. If all else fails, try reinstalling the system:
   ```bash
   ./meetingminutesats.sh setup
   ```

## Reporting Issues

If you encounter issues that you cannot resolve, please report them with the following information:

1. Description of the issue
2. Steps to reproduce the issue
3. Expected result
4. Actual result
5. Log files and error messages
6. System information (OS version, hardware, etc.)

## Next Steps

After completing the tests, you can:

1. Start using the system for transcribing meetings
2. Customize the system settings using the configuration manager
3. Set up automatic transcription using folder monitoring or Raycast integration
4. Explore advanced features such as quality validation and maintenance
