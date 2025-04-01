#!/usr/bin/env python3
# Core Transcription Module for MeetingMinutesATS
# Uses whisper-large-v3-q4 model with MLX optimization

import os
import sys
import time
import json
import argparse
import numpy as np
from pathlib import Path
from typing import Dict, List, Optional, Tuple, Union

# Debug information
print("Python executable:", sys.executable)
print("Python version:", sys.version)
print("Python path:", sys.path)

# Import MLX framework
try:
    print("Attempting to import mlx...")
    import mlx
    print("MLX imported successfully")
    
    print("Attempting to import mlx.core...")
    import mlx.core as mx
    
    print("Attempting to import mlx_whisper...")
    import mlx_whisper
    from mlx_whisper import transcribe
    
    print("All imports successful!")
except ImportError as e:
    print(f"Error: MLX framework not found: {e}")
    print("Please install with 'pip install mlx==0.24.1 mlx_whisper'")
    sys.exit(1)

# Define constants
MODEL_NAME = "large-v3"
MODEL_QUANT = "q4_0"
MODEL_PATH = os.path.expanduser("~/models/whisper-large-v3-mlx/weights.npz")
DEFAULT_LANGUAGE = "zh"
DEFAULT_PROMPT = "會議語言:繁體中文70%,英文30%"
DEFAULT_BEAM_SIZE = 5
DEFAULT_TEMPERATURE = 0.2
DEFAULT_CHUNK_SIZE = 300  # seconds
DEFAULT_OUTPUT_DIR = "./transcriptions"

class MemoryGuard:
    """Context manager for memory management during transcription"""
    
    def __enter__(self):
        try:
            # Try newer API (0.24.1+)
            self.start_mem = mx.get_active_memory() if hasattr(mx, 'get_active_memory') else 0
        except:
            self.start_mem = 0
        return self
        
    def __exit__(self, *args):
        # MLX 0.24.1 doesn't have gc() method
        try:
            # Try newer API (0.24.1+)
            if hasattr(mx, 'get_active_memory'):
                current_mem = mx.get_active_memory()
                if current_mem > self.start_mem * 1.2:
                    if hasattr(mx, 'clear_cache'):
                        mx.clear_cache()
                print(f"Memory reclaimed, current usage: {current_mem/1e9:.1f}GB")
            else:
                print("Memory management not available in this MLX version")
        except Exception as e:
            print(f"Memory management error: {e}")


class WhisperTranscriber:
    """Main transcription class using whisper-large-v3-q4 model"""
    
    def __init__(
        self,
        model_name: str = MODEL_NAME,
        model_path: str = MODEL_PATH,
        quant: str = MODEL_QUANT,
        language: str = DEFAULT_LANGUAGE,
        beam_size: int = DEFAULT_BEAM_SIZE,
        temperature: float = DEFAULT_TEMPERATURE,
        initial_prompt: str = DEFAULT_PROMPT,
        chunk_size: int = DEFAULT_CHUNK_SIZE,
        output_dir: str = DEFAULT_OUTPUT_DIR,
    ):
        self.model_name = model_name
        self.model_path = model_path
        self.quant = quant
        self.language = language
        self.beam_size = beam_size
        self.temperature = temperature
        self.initial_prompt = initial_prompt
        self.chunk_size = chunk_size
        self.output_dir = output_dir
        
        # Create output directory if it doesn't exist
        os.makedirs(output_dir, exist_ok=True)
        
        # Check if model file exists
        if not os.path.exists(self.model_path):
            print(f"Model file not found at {self.model_path}")
            print("Downloading model...")
            os.makedirs(os.path.dirname(self.model_path), exist_ok=True)
            os.system(f"wget https://huggingface.co/mlx-community/whisper-large-v3-mlx/resolve/main/weights.npz -P {os.path.dirname(self.model_path)}")
        
        print(f"Using model path: {self.model_path}")
        try:
            if hasattr(mx, 'metal'):
                print(f"Metal memory before loading: {mx.metal.get_active_memory()/1e9:.1f}GB")
            else:
                print("Metal memory reporting not available.")
        except Exception as e:
            print("Metal memory reporting not available.")
    
    def _format_timestamp(self, seconds: float) -> str:
        """Format seconds to SRT timestamp format: HH:MM:SS,mmm"""
        hours = int(seconds // 3600)
        seconds %= 3600
        minutes = int(seconds // 60)
        seconds %= 60
        milliseconds = int((seconds - int(seconds)) * 1000)
        return f"{hours:02d}:{minutes:02d}:{int(seconds):02d},{milliseconds:03d}"
    
    def _save_as_srt(self, result: Dict, output_path: str) -> None:
        """Save transcription result as SRT subtitle file"""
        srt_path = output_path.rsplit(".", 1)[0] + ".transcript.srt"
        
        with open(srt_path, "w", encoding="utf-8") as f:
            for i, segment in enumerate(result["segments"]):
                # SRT index (starting from 1)
                f.write(f"{i+1}\n")
                
                # Timestamps
                start_time = self._format_timestamp(segment["start"])
                end_time = self._format_timestamp(segment["end"])
                f.write(f"{start_time} --> {end_time}\n")
                
                # Text content
                f.write(f"{segment['text'].strip()}\n\n")
        
        print(f"SRT subtitle file saved to {srt_path}")
    
    def _process_audio_chunk(self, audio_path: str, start_time: float, end_time: float) -> Dict:
        """Process a chunk of audio and return the transcription"""
        chunk_file = f"temp_chunk_{int(start_time)}_{int(end_time)}.wav"
        
        # Extract chunk using ffmpeg
        os.system(f"ffmpeg -y -i {audio_path} -ss {start_time} -to {end_time} -c:a pcm_s16le -ar 16000 -ac 1 {chunk_file} -loglevel error")
        
        # Transcribe chunk
        with MemoryGuard():
            result = mlx_whisper.transcribe(
                chunk_file,
                path_or_hf_repo="mlx-community/whisper-large-v3-mlx",  # Use HF repo instead of local path
                language=self.language,
                temperature=self.temperature,
                initial_prompt=self.initial_prompt,
            )
        
        # Clean up temporary file
        os.remove(chunk_file)
        
        # Add timing information
        result["start_time"] = start_time
        result["end_time"] = end_time
        
        return result
    
    def get_audio_duration(self, audio_path: str) -> float:
        """Get the duration of an audio file using ffmpeg"""
        import subprocess
        
        cmd = f"ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 {audio_path}"
        output = subprocess.check_output(cmd, shell=True).decode('utf-8').strip()
        return float(output)
    
    def transcribe(self, audio_path: str, output_path: Optional[str] = None) -> Dict:
        """Transcribe an audio file with chunking for memory efficiency"""
        start_time = time.time()
        print(f"Starting transcription of {audio_path}...")
        
        # Get audio duration
        duration = self.get_audio_duration(audio_path)
        print(f"Audio duration: {duration:.2f} seconds")
        
        # Determine output path
        if output_path is None:
            base_name = os.path.basename(audio_path).rsplit(".", 1)[0]
            output_path = os.path.join(self.output_dir, f"{base_name}.json")
        
        # Process audio in chunks
        chunks = []
        for chunk_start in range(0, int(duration), self.chunk_size):
            chunk_end = min(chunk_start + self.chunk_size, duration)
            print(f"Processing chunk {chunk_start}-{chunk_end} seconds...")
            
            # Process chunk
            chunk_result = self._process_audio_chunk(audio_path, chunk_start, chunk_end)
            chunks.append(chunk_result)
            
            # Save incremental results
            self._save_incremental_result(chunks, output_path)
            
            # Log memory usage
            try:
                if hasattr(mx, 'metal'):
                    print(f"Metal memory after chunk: {mx.metal.get_active_memory()/1e9:.1f}GB")
                else:
                    print("Chunk processed successfully.")
            except Exception as e:
                print("Chunk processed successfully. Memory usage reporting not available.")
        
        # Combine chunks
        full_result = self._combine_chunks(chunks)
        
        # Save final result as JSON
        with open(output_path, "w", encoding="utf-8") as f:
            json.dump(full_result, f, ensure_ascii=False, indent=2)
        
        # Save as SRT format
        self._save_as_srt(full_result, output_path)
        
        end_time = time.time()
        processing_time = end_time - start_time
        real_time_factor = duration / processing_time
        
        print(f"Transcription completed in {processing_time:.2f} seconds")
        print(f"Real-time factor: {real_time_factor:.2f}x")
        print(f"JSON output saved to {output_path}")
        
        return full_result
    
    def _save_incremental_result(self, chunks: List[Dict], output_path: str) -> None:
        """Save incremental results to a file"""
        temp_output = output_path + ".temp"
        with open(temp_output, "w", encoding="utf-8") as f:
            json.dump(chunks, f, ensure_ascii=False, indent=2)
    
    def _combine_chunks(self, chunks: List[Dict]) -> Dict:
        """Combine transcription chunks into a single result"""
        combined = {
            "text": "",
            "segments": [],
            "language": self.language,
        }
        
        for chunk in chunks:
            combined["text"] += chunk["text"] + " "
            
            # Adjust segment timings
            for segment in chunk["segments"]:
                segment["start"] += chunk["start_time"]
                segment["end"] += chunk["start_time"]
                combined["segments"].append(segment)
        
        return combined


def main():
    parser = argparse.ArgumentParser(description="MeetingMinutesATS Transcription Module")
    parser.add_argument("audio_path", help="Path to the audio file to transcribe")
    parser.add_argument("--output", "-o", help="Output file path (default: auto-generated)")
    parser.add_argument("--model", default=MODEL_NAME, help=f"Model name (default: {MODEL_NAME})")
    parser.add_argument("--quant", default=MODEL_QUANT, help=f"Quantization level (default: {MODEL_QUANT})")
    parser.add_argument("--language", default=DEFAULT_LANGUAGE, help=f"Language code (default: {DEFAULT_LANGUAGE})")
    parser.add_argument("--beam_size", type=int, default=DEFAULT_BEAM_SIZE, help=f"Beam size (default: {DEFAULT_BEAM_SIZE})")
    parser.add_argument("--temperature", type=float, default=DEFAULT_TEMPERATURE, help=f"Temperature (default: {DEFAULT_TEMPERATURE})")
    parser.add_argument("--initial_prompt", default=DEFAULT_PROMPT, help=f"Initial prompt (default: {DEFAULT_PROMPT})")
    parser.add_argument("--chunk_size", type=int, default=DEFAULT_CHUNK_SIZE, help=f"Chunk size in seconds (default: {DEFAULT_CHUNK_SIZE})")
    parser.add_argument("--output_dir", default=DEFAULT_OUTPUT_DIR, help=f"Output directory (default: {DEFAULT_OUTPUT_DIR})")
    
    args = parser.parse_args()
    
    # Initialize transcriber
    transcriber = WhisperTranscriber(
        model_name=args.model,
        quant=args.quant,
        language=args.language,
        beam_size=args.beam_size,
        temperature=args.temperature,
        initial_prompt=args.initial_prompt,
        chunk_size=args.chunk_size,
        output_dir=args.output_dir,
    )
    
    # Transcribe audio
    transcriber.transcribe(args.audio_path, args.output)


if __name__ == "__main__":
    main()
