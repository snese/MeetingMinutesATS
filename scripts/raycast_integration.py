#!/usr/bin/env python3
"""
MeetingMinutesATS Recording Script (Python Version)
This script provides a dialog interface for recording and transcribing meetings
"""

import os
import sys
import time
import subprocess
import datetime
import tkinter as tk
from tkinter import simpledialog, messagebox
from threading import Thread

# Get project path
HOME = os.path.expanduser("~")
PROJECT_PATH = os.path.join(HOME, "Documents/Projects/MeetingMinutesATS")
RECORDINGS_DIR = os.path.join(PROJECT_PATH, "recordings")
TRANSCRIPTIONS_DIR = os.path.join(PROJECT_PATH, "transcriptions")

# Ensure directories exist
os.makedirs(RECORDINGS_DIR, exist_ok=True)
os.makedirs(TRANSCRIPTIONS_DIR, exist_ok=True)

def check_sox_installed():
    """Check if SoX (for 'rec' command) is installed"""
    try:
        subprocess.run(["which", "rec"], check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        return True
    except subprocess.CalledProcessError:
        return False

def get_python_path():
    """Get the path to the Python interpreter"""
    venv_path = os.path.join(PROJECT_PATH, ".venv/bin/python")
    if os.path.exists(venv_path):
        return venv_path
    
    pyenv_path = os.path.join(HOME, ".pyenv/versions/whisper-env/bin/python")
    if os.path.exists(pyenv_path):
        return pyenv_path
    
    return "python3"  # Fallback to system Python

def show_notification(title, message):
    """Show a notification using osascript"""
    applescript = f'display notification "{message}" with title "{title}"'
    subprocess.run(["osascript", "-e", applescript], check=False)

def record_audio(duration, output_path, progress_callback=None):
    """Record audio for the specified duration"""
    # Start recording process
    process = subprocess.Popen(
        ["rec", output_path, "trim", "0", str(duration)],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE
    )
    
    # Show progress
    for i in range(duration):
        if progress_callback:
            progress_callback(i, duration)
        time.sleep(1)
        
        # Check if process is still running
        if process.poll() is not None:
            break
    
    # Make sure process is terminated
    if process.poll() is None:
        process.terminate()
        process.wait()
    
    return process.returncode == 0

def transcribe_audio(audio_path):
    """Transcribe the audio file"""
    python_path = get_python_path()
    transcribe_script = os.path.join(PROJECT_PATH, "src/transcribe.py")
    
    # Run transcription
    result = subprocess.run(
        [python_path, transcribe_script, audio_path],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE
    )
    
    if result.returncode != 0:
        return False, result.stderr.decode('utf-8')
    
    # Get base name for post-processing
    base_name = os.path.splitext(os.path.basename(audio_path))[0]
    json_path = os.path.join(TRANSCRIPTIONS_DIR, f"{base_name}.json")
    
    # Run post-processing
    postprocess_script = os.path.join(PROJECT_PATH, "src/postprocess.py")
    result = subprocess.run(
        [python_path, postprocess_script, json_path],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE
    )
    
    if result.returncode != 0:
        return False, result.stderr.decode('utf-8')
    
    text_output = os.path.join(TRANSCRIPTIONS_DIR, f"{base_name}.processed.txt")
    return True, text_output

def main():
    # Initialize tkinter
    root = tk.Tk()
    root.withdraw()  # Hide the main window
    
    # Check if SoX is installed
    if not check_sox_installed():
        messagebox.showerror(
            "Error", 
            "SoX audio tool is not installed. Please run 'brew install sox' and try again."
        )
        return
    
    # Ask for recording duration
    duration = simpledialog.askinteger(
        "會議錄音", 
        "開始會議錄音嗎? 請輸入錄音時間(秒):",
        initialvalue=60,
        minvalue=1,
        maxvalue=3600
    )
    
    if not duration:
        return
    
    # Generate output filename with timestamp
    timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    output_file = f"meeting_{timestamp}.wav"
    output_path = os.path.join(RECORDINGS_DIR, output_file)
    
    # Create progress window
    progress_window = tk.Toplevel(root)
    progress_window.title("Recording in progress...")
    progress_window.geometry("300x100")
    
    progress_label = tk.Label(progress_window, text=f"Recording: 0/{duration} seconds")
    progress_label.pack(pady=10)
    
    progress_bar = tk.Scale(
        progress_window, 
        from_=0, 
        to=100, 
        orient=tk.HORIZONTAL, 
        length=250,
        state=tk.DISABLED
    )
    progress_bar.pack(pady=10)
    
    # Define progress callback
    def update_progress(current, total):
        progress_percent = int(current * 100 / total)
        progress_bar.set(progress_percent)
        progress_label.config(text=f"Recording: {current}/{total} seconds")
        progress_window.update()
    
    # Start recording in a separate thread
    def recording_thread():
        success = record_audio(duration, output_path, update_progress)
        progress_window.destroy()
        
        if not success:
            messagebox.showerror("Error", "Recording failed")
            return
        
        # Ask if user wants to transcribe now
        if messagebox.askyesno(
            "Recording Complete", 
            f"錄音已保存到 {output_path}。是否立即轉錄?"
        ):
            # Show transcription progress
            messagebox.showinfo("Transcription", "Transcription started...")
            
            # Run transcription
            success, result = transcribe_audio(output_path)
            
            if not success:
                messagebox.showerror("Error", f"Transcription failed: {result}")
                return
            
            # Show success and offer to open the file
            if messagebox.askyesno(
                "Transcription Complete", 
                "轉錄完成！是否打開文件?"
            ):
                subprocess.run(["open", result], check=False)
    
    # Start the recording thread
    Thread(target=recording_thread).start()
    
    # Start the main loop
    root.mainloop()

if __name__ == "__main__":
    main()
