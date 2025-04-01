#!/usr/bin/osascript

-- MeetingMinutesATS Recording Script
-- This script provides a dialog interface for recording and transcribing meetings

-- Ask for recording duration
set dialogResult to display dialog "開始會議錄音嗎?" default answer "60" buttons {"取消", "開始"} default button "開始"
if button returned of dialogResult is "取消" then
    return
end if

-- Get duration from input
set duration to text returned of dialogResult as integer

-- Generate output filename with timestamp
set timestamp to do shell script "date +%Y%m%d_%H%M%S"
set output_file to "meeting_" & timestamp & ".wav"
set project_path to do shell script "echo $HOME/Documents/Projects/MeetingMinutesATS"
set output_path to project_path & "/recordings/" & output_file

-- Create recordings directory if it doesn't exist
do shell script "mkdir -p " & quoted form of (project_path & "/recordings")

-- Check if SoX (for 'rec' command) is installed
try
    do shell script "which rec"
on error
    display dialog "Error: SoX audio tool is not installed. Please run 'brew install sox' and try again." buttons {"OK"} default button "OK"
    return
end try

-- Tell user recording is starting
display notification "Recording started for " & duration & " seconds" with title "Meeting Recorder"

-- Start recording with improved error handling
try
    do shell script "rec " & quoted form of output_path & " trim 0 " & duration
on error error_message
    display dialog "Recording failed: " & error_message buttons {"OK"} default button "OK"
    return
end try

-- Tell user recording is complete
display notification "Recording completed!" with title "Meeting Recorder"

-- Ask if user wants to transcribe now
set transcribe_choice to button returned of (display dialog "錄音已保存到 " & output_path & "。是否立即轉錄?" buttons {"稍後", "立即轉錄"} default button "立即轉錄")

if transcribe_choice is "立即轉錄" then
    display notification "Transcription started..." with title "Meeting Recorder"
    
    try
        -- Run transcription with improved Python path detection
        set python_path to "/Users/$(whoami)/.pyenv/versions/whisper-env/bin/python"
        if not my file_exists(python_path) then
            set python_path to project_path & "/.venv/bin/python"
            if not my file_exists(python_path) then
                set python_path to do shell script "which python3"
            end if
        end if
        
        set transcribe_script to project_path & "/src/transcribe.py"
        do shell script quoted form of python_path & " " & quoted form of transcribe_script & " " & quoted form of output_path
        
        -- Run post-processing
        set base_name to do shell script "basename " & quoted form of output_path & " .wav"
        set json_path to project_path & "/transcriptions/" & base_name & ".json"
        set postprocess_script to project_path & "/src/postprocess.py"
        do shell script quoted form of python_path & " " & quoted form of postprocess_script & " " & quoted form of json_path
        
        -- Get output path
        set text_output to project_path & "/transcriptions/" & base_name & ".processed.txt"
        
        -- Show success and offer to open the file
        set open_choice to button returned of (display dialog "轉錄完成！是否打開文件?" buttons {"否", "是"} default button "是")
        if open_choice is "是" then
            do shell script "open " & quoted form of text_output
        end if
        
    on error error_message
        display dialog "轉錄失敗: " & error_message buttons {"確定"} default button "確定"
    end try
end if

-- Helper function to check if a file exists
on file_exists(theFile)
    try
        do shell script "test -e " & quoted form of theFile
        return true
    on error
        return false
    end try
end file_exists
