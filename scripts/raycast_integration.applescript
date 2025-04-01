#!/usr/bin/osascript

-- MeetingMinutesATS Recording Script
-- This script provides a dialog interface for recording and transcribing meetings

on run
    -- Ask for recording duration in minutes
    set dialogResult to display dialog "開始會議錄音嗎? 請輸入錄音時間(分鐘)" default answer "1" buttons {"取消", "開始"} default button "開始"
    if button returned of dialogResult is "取消" then
        return
    end if
    
    -- Get duration from input (convert to seconds)
    set duration_minutes to text returned of dialogResult as integer
    set duration_seconds to duration_minutes * 60
    
    -- Check if SwitchAudioSource is installed
    set switchAudioInstalled to false
    try
        do shell script "which SwitchAudioSource"
        set switchAudioInstalled to true
    on error
        display dialog "SwitchAudioSource not found. Will use default input source. For input source selection, install with 'brew install switchaudio-osx'" buttons {"Continue"} default button "Continue"
    end try
    
    -- Ask for input source if SwitchAudioSource is installed
    set input_source to "default"
    if switchAudioInstalled then
        try
            -- Get full device list
            set input_sources_raw to do shell script "SwitchAudioSource -a -t input"
            set input_source_list to paragraphs of input_sources_raw
            
            -- Filter empty lines
            set device_names to {}
            repeat with i from 1 to count of input_source_list
                if length of item i of input_source_list > 0 then
                    set device_name to item i of input_source_list
                    set end of device_names to device_name
                end if
            end repeat
            
            if (count of device_names) > 0 then
                set input_source_choice to choose from list device_names with prompt "選擇錄音輸入源:" default items (item 1 of device_names)
                if input_source_choice is false then
                    return
                end if
                set selected_device to item 1 of input_source_choice
                
                -- Set the selected input device as active
                do shell script "SwitchAudioSource -s " & quoted form of selected_device & " -t input"
                set input_source to selected_device
            end if
        on error error_message
            display dialog "Error getting input sources: " & error_message & ". Using default input." buttons {"OK"} default button "OK"
        end try
    end if
    
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
    
    -- Calculate end time for display
    set end_time to do shell script "date -v +" & duration_seconds & "S '+%H:%M:%S'"
    
    -- Tell user recording is starting
    display notification "Recording started for " & duration_minutes & " minutes using " & input_source & ". Will complete at " & end_time with title "Meeting Recorder"
    
    -- Start recording in background
    do shell script "rec " & quoted form of output_path & " trim 0 " & duration_seconds & " &"
    
    -- Get the process ID of the recording
    set rec_pid to do shell script "ps -ef | grep 'rec.*" & output_file & "' | grep -v grep | awk '{print $2}'"
    
    -- Create a menu bar item to show recording status and allow cancellation
    set menu_bar_script to "
    tell application \"System Events\"
        set statusItem to make new menu bar item at end of menu bar 1
        set statusMenu to make new menu at end of menu bar item statusItem
        set menuTitle to make new menu item with properties {title:\"🔴 Recording... (Ends at " & end_time & ")\"} at beginning of statusMenu
        set cancelItem to make new menu item with properties {title:\"Cancel Recording\"} at end of statusMenu
        
        repeat until (current date) > (date \"" & end_time & "\")
            delay 1
            -- Check if user clicked cancel
            if exists menu item \"Cancel Recording\" of statusMenu then
                if (get enabled of menu item \"Cancel Recording\" of statusMenu) is false then
                    do shell script \"kill " & rec_pid & "\"
                    do shell script \"rm -f " & output_path & "\"
                    set title of menuTitle to \"Recording Canceled\"
                    delay 2
                    delete statusItem
                    return
                end if
            end if
        end repeat
        
        set title of menuTitle to \"Recording Complete\"
        delay 2
        delete statusItem
    end tell
    "
    
    -- Run the menu bar script in background
    do shell script "osascript -e '" & menu_bar_script & "' &"
    
    -- Wait for recording to complete
    do shell script "sleep " & duration_seconds
    
    -- Check if the recording process is still running
    try
        set is_running to do shell script "ps -p " & rec_pid & " > /dev/null 2>&1 && echo 'yes' || echo 'no'"
        if is_running is "yes" then
            -- Recording completed normally
            display notification "Recording completed!" with title "Meeting Recorder"
        else
            -- Recording was canceled
            return
        end if
    on error
        -- Process not found, assume recording completed or was canceled
        return
    end try
    
    -- Ask if user wants to transcribe now
    set transcribeDialog to display dialog "錄音已保存到 " & output_path & "。是否立即轉錄?" buttons {"稍後", "立即轉錄"} default button "立即轉錄"
    set transcribe_choice to button returned of transcribeDialog
    
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
            do shell script quoted form of python_path & " " & quoted form of postprocess_script & " " & quoted form of json_path & " --md-only"
            
            -- Get output path
            set md_output to project_path & "/transcriptions/" & base_name & ".transcript.md"
            
            -- Show success and offer to open the file
            set openDialog to display dialog "轉錄完成！是否打開文件?" buttons {"否", "是"} default button "是"
            set open_choice to button returned of openDialog
            
            if open_choice is "是" then
                do shell script "open " & quoted form of md_output
            end if
            
        on error error_message
            display dialog "轉錄失敗: " & error_message buttons {"確定"} default button "確定"
        end try
    end if
end run

-- Helper function to check if a file exists
on file_exists(theFile)
    try
        do shell script "test -e " & quoted form of theFile
        return true
    on error
        return false
    end try
end file_exists
