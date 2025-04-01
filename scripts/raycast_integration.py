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
from tkinter import simpledialog, messagebox, ttk
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
    # Prioritize pyenv path which we know exists
    pyenv_path = os.path.join(HOME, ".pyenv/versions/whisper-env/bin/python")
    if os.path.exists(pyenv_path):
        return pyenv_path
    
    venv_path = os.path.join(PROJECT_PATH, ".venv/bin/python")
    if os.path.exists(venv_path):
        return venv_path
    
    return "python3"  # Fallback to system Python

def show_notification(title, message):
    """Show a notification using osascript"""
    applescript = f'display notification "{message}" with title "{title}"'
    subprocess.run(["osascript", "-e", applescript], check=False)

def get_input_sources():
    """Get available audio input sources"""
    try:
        # Try using SwitchAudioSource
        result = subprocess.run(
            ["SwitchAudioSource", "-a", "-t", "input"],
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        sources = []
        for line in result.stdout.splitlines():
            if line.strip():
                sources.append(line.strip())
        return sources if sources else ["default"]
    except (subprocess.CalledProcessError, FileNotFoundError):
        # Try using system_profiler as fallback
        try:
            result = subprocess.run(
                ["system_profiler", "SPAudioDataType"],
                check=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True
            )
            sources = []
            in_input_section = False
            for line in result.stdout.splitlines():
                if "Input Devices:" in line:
                    in_input_section = True
                elif in_input_section and ":" in line and not line.strip().startswith("Input"):
                    device = line.split(":")[0].strip()
                    if device:
                        sources.append(device)
                elif in_input_section and line.strip() == "":
                    in_input_section = False
            return sources if sources else ["default"]
        except subprocess.CalledProcessError:
            return ["default"]

def set_input_source(source):
    """Set the active input source"""
    if source != "default":
        try:
            subprocess.run(
                ["SwitchAudioSource", "-s", source, "-t", "input"],
                check=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE
            )
            return True
        except (subprocess.CalledProcessError, FileNotFoundError) as e:
            print(f"Error setting input source: {e}", file=sys.stderr)
            return False
    return True

def format_time(seconds):
    """Format seconds as MM:SS"""
    minutes = seconds // 60
    seconds = seconds % 60
    return f"{minutes:02d}:{seconds:02d}"

def record_audio(duration, output_path, input_source="default", progress_callback=None):
    """Record audio for the specified duration"""
    try:
        # Set the input source if specified
        if input_source != "default":
            success = set_input_source(input_source)
            if not success:
                print(f"Warning: Could not set input source to {input_source}", file=sys.stderr)
        
        # Use a simpler recording command
        cmd = ["rec", output_path, "trim", "0", str(duration)]
        
        # Start recording process
        process = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE
        )
        
        # Show progress
        start_time = time.time()
        end_time = start_time + duration
        
        while time.time() < end_time:
            if process.poll() is not None:
                # Process ended prematurely
                break
                
            elapsed = time.time() - start_time
            remaining = duration - elapsed
            
            if progress_callback:
                progress_callback(elapsed, duration, remaining)
            
            time.sleep(0.5)
        
        # Make sure process is terminated
        if process.poll() is None:
            process.terminate()
            process.wait()
        
        # Check if the process completed successfully
        if process.returncode != 0:
            stderr = process.stderr.read().decode('utf-8')
            print(f"Recording error: {stderr}", file=sys.stderr)
            return False
            
        return True
    except Exception as e:
        print(f"Recording exception: {str(e)}", file=sys.stderr)
        return False

def transcribe_audio(audio_path):
    """Transcribe the audio file"""
    try:
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
    except Exception as e:
        return False, str(e)

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
    
    # Get available input sources
    input_sources = get_input_sources()
    
    # Create setup dialog
    setup_dialog = tk.Toplevel(root)
    setup_dialog.title("會議錄音設置")
    setup_dialog.geometry("400x200")
    setup_dialog.resizable(False, False)
    
    # Center the window
    setup_dialog.update_idletasks()
    width = setup_dialog.winfo_width()
    height = setup_dialog.winfo_height()
    x = (setup_dialog.winfo_screenwidth() // 2) - (width // 2)
    y = (setup_dialog.winfo_screenheight() // 2) - (height // 2)
    setup_dialog.geometry(f"{width}x{height}+{x}+{y}")
    
    # Duration frame
    duration_frame = tk.Frame(setup_dialog)
    duration_frame.pack(fill="x", padx=20, pady=10)
    
    tk.Label(duration_frame, text="錄音時間 (分鐘):").pack(side="left")
    duration_var = tk.StringVar(value="1")
    duration_entry = tk.Spinbox(
        duration_frame, 
        from_=1, 
        to=60, 
        textvariable=duration_var,
        width=5
    )
    duration_entry.pack(side="left", padx=5)
    
    # Input source frame
    source_frame = tk.Frame(setup_dialog)
    source_frame.pack(fill="x", padx=20, pady=10)
    
    tk.Label(source_frame, text="輸入源:").pack(side="left")
    source_var = tk.StringVar(value=input_sources[0] if input_sources else "default")
    source_dropdown = ttk.Combobox(
        source_frame, 
        textvariable=source_var,
        values=input_sources,
        width=25
    )
    source_dropdown.pack(side="left", padx=5, fill="x", expand=True)
    
    # Buttons frame
    button_frame = tk.Frame(setup_dialog)
    button_frame.pack(fill="x", padx=20, pady=20)
    
    cancel_button = tk.Button(
        button_frame, 
        text="取消", 
        command=lambda: setup_dialog.destroy()
    )
    cancel_button.pack(side="left", padx=5)
    
    start_button = tk.Button(
        button_frame, 
        text="開始錄音", 
        command=lambda: start_recording()
    )
    start_button.pack(side="right", padx=5)
    
    # Function to start recording
    def start_recording():
        try:
            # Get values from dialog
            duration_minutes = int(duration_var.get())
            duration_seconds = duration_minutes * 60
            input_source = source_var.get()
            
            # Close setup dialog
            setup_dialog.destroy()
            
            # Generate output filename with timestamp
            timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
            output_file = f"meeting_{timestamp}.wav"
            output_path = os.path.join(RECORDINGS_DIR, output_file)
            
            # Create progress window
            progress_window = tk.Toplevel(root)
            progress_window.title("錄音進行中...")
            progress_window.geometry("400x150")
            progress_window.resizable(False, False)
            
            # Center the window
            progress_window.update_idletasks()
            width = progress_window.winfo_width()
            height = progress_window.winfo_height()
            x = (progress_window.winfo_screenwidth() // 2) - (width // 2)
            y = (progress_window.winfo_screenheight() // 2) - (height // 2)
            progress_window.geometry(f"{width}x{height}+{x}+{y}")
            
            # Progress labels
            status_label = tk.Label(
                progress_window, 
                text=f"正在錄音 ({duration_minutes} 分鐘)...",
                font=("Helvetica", 12)
            )
            status_label.pack(pady=(15, 5))
            
            time_label = tk.Label(
                progress_window, 
                text="00:00 / " + format_time(duration_seconds),
                font=("Helvetica", 10)
            )
            time_label.pack(pady=5)
            
            # Progress bar
            progress_bar = ttk.Progressbar(
                progress_window, 
                orient="horizontal", 
                length=350, 
                mode="determinate"
            )
            progress_bar.pack(pady=10, padx=25)
            
            # Cancel button
            cancel_button = tk.Button(
                progress_window, 
                text="取消", 
                command=lambda: cancel_recording()
            )
            cancel_button.pack(pady=10)
            
            # Recording process
            recording_process = None
            
            # Function to cancel recording
            def cancel_recording():
                nonlocal recording_process
                if recording_process and recording_process.is_alive():
                    # Set a flag to stop the recording
                    recording_process.cancel = True
                progress_window.destroy()
            
            # Define progress callback
            def update_progress(elapsed, total, remaining):
                progress_percent = int(elapsed * 100 / total)
                progress_bar["value"] = progress_percent
                time_label.config(text=f"{format_time(int(elapsed))} / {format_time(int(total))}")
                status_label.config(text=f"正在錄音 ({duration_minutes} 分鐘)... {progress_percent}%")
                progress_window.update()
            
            # Start recording in a separate thread
            def recording_thread():
                thread = Thread(target=recording_process_thread)
                thread.cancel = False
                thread.daemon = True
                thread.start()
                return thread
            
            def recording_process_thread():
                try:
                    success = record_audio(duration_seconds, output_path, input_source, update_progress)
                    
                    # Check if the thread was cancelled
                    if hasattr(recording_process, 'cancel') and recording_process.cancel:
                        # Delete the partial recording file
                        if os.path.exists(output_path):
                            os.remove(output_path)
                        return
                    
                    # Close progress window
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
                except Exception as e:
                    messagebox.showerror("Error", f"An unexpected error occurred: {str(e)}")
            
            # Start the recording thread
            recording_process = recording_thread()
            
        except Exception as e:
            messagebox.showerror("Error", f"Setup error: {str(e)}")
    
    # Start the main loop
    root.mainloop()

if __name__ == "__main__":
    main()
