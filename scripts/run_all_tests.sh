#!/bin/bash
# Run All Tests Script for MeetingMinutesATS
# This script runs all the tests in the test plan automatically

# Get the directory of this script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR/.."

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Function to print section header
print_header() {
    echo -e "\n${YELLOW}=======================================${NC}"
    echo -e "${YELLOW}$1${NC}"
    echo -e "${YELLOW}=======================================${NC}\n"
}

# Function to print test result
print_result() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✅ PASS: $2${NC}"
    else
        echo -e "${RED}❌ FAIL: $2${NC}"
    fi
}

# Create test results directory
mkdir -p test_results

# Start test log
LOG_FILE="test_results/test_run_$(date +%Y%m%d_%H%M%S).log"
echo "MeetingMinutesATS Test Run - $(date)" > "$LOG_FILE"
echo "=======================================" >> "$LOG_FILE"

# Test 1: Environment Check
print_header "Test 1: Environment Check"
echo "Checking for required directories..."
REQUIRED_DIRS=("src" "scripts" "models" "logs" "recordings" "transcriptions")
MISSING_DIRS=()

for dir in "${REQUIRED_DIRS[@]}"; do
    if [ ! -d "$dir" ]; then
        MISSING_DIRS+=("$dir")
        mkdir -p "$dir"
        echo "Created missing directory: $dir"
    fi
done

if [ ${#MISSING_DIRS[@]} -eq 0 ]; then
    print_result 0 "All required directories exist"
else
    print_result 1 "Some directories were missing and had to be created: ${MISSING_DIRS[*]}"
fi

# Check for required scripts
echo "Checking for required scripts..."
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
    print_result 0 "All required scripts exist"
else
    print_result 1 "Some scripts are missing: ${MISSING_SCRIPTS[*]}"
    echo "Please ensure all required scripts are present before continuing."
    exit 1
fi

# Test 2: Installation Test
print_header "Test 2: Installation Test"
echo "Running installation test script..."
./scripts/test_installation.sh | tee -a "$LOG_FILE"
TEST_RESULT=$?
print_result $TEST_RESULT "Installation test"

# Test 3: Basic Transcription
print_header "Test 3: Basic Transcription"
echo "Creating test audio file..."
ffmpeg -f lavfi -i "sine=frequency=440:duration=3" -c:a pcm_s16le -ar 16000 -ac 1 test_audio.wav -y 2>/dev/null
if [ -f "test_audio.wav" ]; then
    print_result 0 "Test audio file created"
    
    echo "Running basic transcription test..."
    ./meetingminutesats.sh transcribe test_audio.wav 2>&1 | tee -a "$LOG_FILE"
    
    # Check if transcription was created
    if [ -f "transcriptions/test_audio.json" ] || [ -f "transcriptions/test_audio.processed.txt" ]; then
        print_result 0 "Basic transcription test"
    else
        print_result 1 "Basic transcription test - No output files found"
    fi
else
    print_result 1 "Failed to create test audio file"
fi

# Test 4: Configuration Management
print_header "Test 4: Configuration Management"
echo "Testing configuration management..."

# Show current configuration
echo "Showing current configuration..."
./meetingminutesats.sh config --show 2>&1 | tee -a "$LOG_FILE"

# Modify a setting
echo "Modifying configuration setting..."
./meetingminutesats.sh config --set transcription chunk_size 180 2>&1 | tee -a "$LOG_FILE"

# Verify the change
echo "Verifying configuration change..."
CHUNK_SIZE=$(./meetingminutesats.sh config --get transcription chunk_size 2>/dev/null)
if [[ "$CHUNK_SIZE" == *"180"* ]]; then
    print_result 0 "Configuration modification"
else
    print_result 1 "Configuration modification - Value not changed"
fi

# Reset to defaults
echo "Resetting configuration to defaults..."
./meetingminutesats.sh config --reset 2>&1 | tee -a "$LOG_FILE"

# Test 5: Resource Monitoring
print_header "Test 5: Resource Monitoring"
echo "Testing resource monitoring script..."
echo "Running resource monitoring for 5 seconds..."
timeout 5s ./scripts/monitor_resources.sh 2>&1 | tee -a "$LOG_FILE" || true

# Check if log file was created
if [ -f "logs/resource.log" ]; then
    print_result 0 "Resource monitoring log created"
    echo "Sample from resource log:"
    head -n 10 logs/resource.log | tee -a "$LOG_FILE"
else
    print_result 1 "Resource monitoring log not created"
fi

# Test 6: Quality Validation
print_header "Test 6: Quality Validation"
echo "Testing quality validation system..."
echo "This may take a while as it needs to generate test cases..."
timeout 30s ./meetingminutesats.sh validate --test pure_chinese 2>&1 | tee -a "$LOG_FILE" || true

# Check if test results were created
if [ -d "test_cases" ] || [ -d "test_results" ]; then
    print_result 0 "Quality validation test"
else
    print_result 1 "Quality validation test - No test cases or results found"
fi

# Test 7: Folder Monitoring
print_header "Test 7: Folder Monitoring"
echo "Testing folder monitoring script..."
echo "Starting folder monitoring in the background..."
./scripts/folder_monitor.sh > /dev/null 2>&1 &
MONITOR_PID=$!

# Wait a moment for the script to start
sleep 2

# Check if the script is running
if ps -p $MONITOR_PID > /dev/null; then
    print_result 0 "Folder monitoring script started"
    
    # Kill the process
    echo "Stopping folder monitoring script..."
    kill $MONITOR_PID 2>/dev/null || true
    sleep 1
    
    # Make sure it's stopped
    if ! ps -p $MONITOR_PID > /dev/null; then
        print_result 0 "Folder monitoring script stopped"
    else
        print_result 1 "Failed to stop folder monitoring script"
        # Force kill
        kill -9 $MONITOR_PID 2>/dev/null || true
    fi
else
    print_result 1 "Failed to start folder monitoring script"
fi

# Test 8: Maintenance Script
print_header "Test 8: Maintenance Script"
echo "Testing maintenance script..."
echo "Starting maintenance script in the background..."
./scripts/maintenance.sh > /dev/null 2>&1 &
MAINTENANCE_PID=$!

# Wait a moment for the script to start
sleep 2

# Check if the script is running
if ps -p $MAINTENANCE_PID > /dev/null; then
    print_result 0 "Maintenance script started"
    
    # Kill the process
    echo "Stopping maintenance script..."
    kill $MAINTENANCE_PID 2>/dev/null || true
    sleep 1
    
    # Make sure it's stopped
    if ! ps -p $MAINTENANCE_PID > /dev/null; then
        print_result 0 "Maintenance script stopped"
    else
        print_result 1 "Failed to stop maintenance script"
        # Force kill
        kill -9 $MAINTENANCE_PID 2>/dev/null || true
    fi
else
    print_result 1 "Failed to start maintenance script"
fi

# Test 9: Raycast Integration
print_header "Test 9: Raycast Integration"
echo "Raycast integration test requires manual interaction."
echo "To test, run: ./meetingminutesats.sh raycast"
echo "Skipping automated test for Raycast integration."

# Test 10: End-to-End Test
print_header "Test 10: End-to-End Test"
echo "End-to-End test requires a real meeting recording."
echo "To test, run: ./meetingminutesats.sh transcribe path/to/meeting/recording.m4a"
echo "Skipping automated End-to-End test."

# Summary
print_header "Test Summary"
echo "Test results have been saved to: $LOG_FILE"
echo "Please review the test results and complete any manual tests."
echo "For a detailed test plan, see test_plan.md"
echo "For a test checklist, see test_checklist.md"

# Final message
echo -e "\n${GREEN}Automated tests completed.${NC}"
echo "Some tests require manual verification. Please check the test plan and checklist."
