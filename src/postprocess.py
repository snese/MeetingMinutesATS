#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Post-processing script for Whisper transcriptions.
This version generates Markdown format transcripts instead of SRT.
"""

import json
import os
import sys
import argparse
from datetime import timedelta

def format_timestamp(seconds, include_ms=False):
    """Format seconds as HH:MM:SS or HH:MM:SS.mmm"""
    ms = int(seconds * 1000) % 1000
    seconds = int(seconds)
    minutes = seconds // 60
    seconds = seconds % 60
    hours = minutes // 60
    minutes = minutes % 60
    
    if include_ms:
        return f"{hours:02d}:{minutes:02d}:{seconds:02d}.{ms:03d}"
    else:
        return f"{hours:02d}:{minutes:02d}:{seconds:02d}"

def generate_markdown_transcript(json_path):
    """Generate Markdown transcript file from JSON transcription"""
    # Get the base filename without extension
    base_name = os.path.splitext(json_path)[0]
    md_path = f"{base_name}.transcript.md"
    
    # Load the JSON data
    with open(json_path, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    # Extract segments
    segments = data.get('segments', [])
    
    # Generate Markdown content
    md_content = []
    for segment in segments:
        start_time = segment.get('start', 0)
        end_time = segment.get('end', 0)
        text = segment.get('text', '').strip()
        
        # Skip empty segments
        if not text:
            continue
        
        # Format as Markdown entry with timestamps
        start_formatted = format_timestamp(start_time)
        end_formatted = format_timestamp(end_time)
        md_entry = f"[{start_formatted} - {end_formatted}] {text}\n\n"
        md_content.append(md_entry)
    
    # Write Markdown file
    with open(md_path, 'w', encoding='utf-8') as f:
        f.write(''.join(md_content))
    
    return md_path

def main():
    parser = argparse.ArgumentParser(description="Post-process Whisper transcription")
    parser.add_argument("json_path", help="Path to the JSON transcription file")
    parser.add_argument("--md-only", action="store_true", help="Only generate Markdown file (default)")
    args = parser.parse_args()
    
    if not os.path.exists(args.json_path):
        print(f"Error: JSON file not found: {args.json_path}")
        sys.exit(1)
    
    # Generate Markdown transcript
    md_path = generate_markdown_transcript(args.json_path)
    print(f"Generated Markdown transcript: {md_path}")

if __name__ == "__main__":
    main()
