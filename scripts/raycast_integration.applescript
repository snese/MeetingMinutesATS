-- Raycast Integration for MeetingMinutesATS
-- This script provides a Raycast interface for recording and transcribing meetings

on run
    tell application "Raycast"
        activate
        
        -- Ask for recording duration
        set input to display dialog "開始會議錄音嗎?" default answer "60" buttons {"取消", "開始"} default button "開始"
        
        -- Check if user canceled
        if button returned of input is "取消" then
            return
        end if
        
        -- Get duration from input
        set duration to text returned of input as integer
        
        -- Generate output filename with timestamp
        set timestamp to do shell script "date +%Y%m%d_%H%M%S"
        set output_file to "meeting_" & timestamp & ".wav"
        set output_path to (do shell script "echo $HOME/Documents/Projects/MeetingMinutesATS/recordings") & "/" & output_file
        
        -- Create recordings directory if it doesn't exist
        do shell script "mkdir -p $HOME/Documents/Projects/MeetingMinutesATS/recordings"
        
        -- Display recording progress
        set progress to display progress "錄音中..." with title "會議錄音" buttons {"停止"}
        
        -- Start recording
        try
            -- Use rec command to record audio
            do shell script "rec " & quoted form of output_path & " trim 0 " & duration & " &"
            
            -- Wait for recording to complete
            repeat with i from 1 to duration
                set progress completed steps to i
                set progress description to "已錄製 " & i & " 秒，共 " & duration & " 秒"
                delay 1
                
                -- Check if user clicked stop
                if progress gave up then
                    do shell script "pkill -f 'rec.*" & output_file & "'"
                    exit repeat
                end if
            end repeat
            
            close progress with result "錄音完成"
            
            -- Ask if user wants to transcribe now
            set transcribe_now to display dialog "錄音已保存到 " & output_path & "。是否立即轉錄?" buttons {"稍後", "立即轉錄"} default button "立即轉錄"
            
            if button returned of transcribe_now is "立即轉錄" then
                -- Show transcription progress
                set progress to display progress "轉錄進度" with title "處理中..."
                
                -- Run transcription
                try
                    set transcribe_cmd to "$HOME/.pyenv/versions/whisper-env/bin/python $HOME/Documents/Projects/MeetingMinutesATS/src/transcribe.py " & quoted form of output_path
                    do shell script transcribe_cmd
                    
                    -- Run post-processing
                    set base_name to do shell script "basename " & quoted form of output_path & " .wav"
                    set json_path to "$HOME/Documents/Projects/MeetingMinutesATS/transcriptions/" & base_name & ".json"
                    set postprocess_cmd to "$HOME/.pyenv/versions/whisper-env/bin/python $HOME/Documents/Projects/MeetingMinutesATS/src/postprocess.py " & json_path
                    do shell script postprocess_cmd
                    
                    -- Get output path
                    set text_output to "$HOME/Documents/Projects/MeetingMinutesATS/transcriptions/" & base_name & ".processed.txt"
                    
                    close progress with result "完成"
                    
                    -- Show success and offer to open the file
                    set open_file to display dialog "轉錄完成！是否打開文件?" buttons {"否", "是"} default button "是"
                    
                    if button returned of open_file is "是" then
                        do shell script "open " & quoted form of text_output
                    end if
                    
                on error error_message
                    close progress with result "失敗"
                    display dialog "轉錄失敗: " & error_message buttons {"確定"} default button "確定"
                end try
            end if
            
        on error error_message
            close progress with result "失敗"
            display dialog "錄音失敗: " & error_message buttons {"確定"} default button "確定"
        end try
    end tell
end run
