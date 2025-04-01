# MeetingMinutesATS Test Checklist

Use this checklist to track your progress through the test plan. Check off each item as you complete it and note any issues or observations.

## Environment Setup

- [ ] Run `./meetingminutesats.sh setup`
- [ ] Verify Homebrew installation
- [ ] Verify pyenv and pyenv-virtualenv installation
- [ ] Verify ffmpeg installation
- [ ] Verify Python 3.10.13 environment creation
- [ ] Verify MLX framework installation

## Installation Test

- [ ] Run `./meetingminutesats.sh test`
- [ ] Verify all components are detected correctly

## Basic Transcription

- [ ] Create or use test audio file
- [ ] Run `./meetingminutesats.sh transcribe test_audio.wav`
- [ ] Verify transcription output in transcriptions directory

## Configuration Management

- [ ] Show current configuration
- [ ] Modify a configuration setting
- [ ] Verify the change
- [ ] Reset to defaults

## Resource Monitoring

- [ ] Run resource monitoring script
- [ ] Verify log file contains memory usage information

## Quality Validation

- [ ] Run quality validation test
- [ ] Verify test cases and evaluation results

## Folder Monitoring

- [ ] Start folder monitoring script
- [ ] Copy audio file to monitored directory
- [ ] Verify file detection and processing
- [ ] Check logs for processing information
- [ ] Stop the background process

## Maintenance Script

- [ ] Run maintenance script
- [ ] Verify log file contains system status information
- [ ] Stop the background process

## Raycast Integration

- [ ] Run Raycast integration script
- [ ] Record a short audio clip
- [ ] Verify transcription option and processing

## End-to-End Test

- [ ] Prepare a meeting recording with mixed Chinese and English
- [ ] Run transcription on the recording
- [ ] Verify accuracy of transcription for both languages

## Notes and Observations

Use this section to note any issues, observations, or suggestions for improvement:

1. 
2. 
3. 

## Overall Assessment

- [ ] All tests passed
- [ ] Some tests failed (see notes)
- [ ] System meets requirements
- [ ] System needs improvements (see notes)
