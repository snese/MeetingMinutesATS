#!/usr/bin/env python3
# Post-processing Module for MeetingMinutesATS
# Handles punctuation correction, speaker segmentation, and text formatting

import os
import re
import json
import argparse
from typing import Dict, List, Optional, Tuple, Union

class PunctuationCorrector:
    """Corrects punctuation in mixed Chinese-English text"""
    
    def __init__(self):
        # Define replacement patterns
        self.replacements = {
            # Chinese-English punctuation conversion
            r'(\w)([，。]) ?([A-Z])': r'\1. \3',
            
            # Date format correction
            r'(\d+)[的]?年': r'\1年',
            
            # English sentence ending correction
            r'([a-zA-Z])([，。])': r'\1.',
            
            # Fix spacing around punctuation
            r'(\w)([.!?]) ?([a-zA-Z])': r'\1\2 \3',
            
            # Fix multiple spaces
            r' +': r' ',
            
            # Fix missing space after period
            r'(\.)([A-Za-z])': r'\1 \2',
            
            # Fix incorrect punctuation combinations
            r'([.!?])([,;])': r'\1',
            
            # Fix quotation marks
            r'"([^"]*)"': r'"\1"',
        }
    
    def correct(self, text: str) -> str:
        """Apply all punctuation corrections to the text"""
        for pattern, repl in self.replacements.items():
            text = re.sub(pattern, repl, text)
        return text


class SpeakerSegmenter:
    """Segments text by potential speaker changes"""
    
    def __init__(self, max_chars: int = 500):
        self.max_chars = max_chars
        
        # Patterns that might indicate speaker changes
        self.speaker_patterns = [
            r'(?:好的|那麼|所以|接下來|首先|最後|另外|此外|然後|但是|不過|因此|總之|總結|謝謝|感謝|請問|我想問|我認為|我覺得)',
            r'(?:[A-Z][a-z]+ said|According to|In my opinion|I think|I believe|Let me|Thank you)',
        ]
        
        # Compile patterns
        self.compiled_patterns = [re.compile(pattern) for pattern in self.speaker_patterns]
    
    def segment_by_speaker(self, text: str) -> List[str]:
        """Segment text by potential speaker changes and maximum character limit"""
        # First split by sentence endings
        sentences = re.split(r'(?<=[。.!?])\s*', text)
        sentences = [s for s in sentences if s.strip()]
        
        segments = []
        current_segment = []
        char_count = 0
        
        for sentence in sentences:
            s_length = len(sentence)
            
            # Check if adding this sentence would exceed max_chars
            if char_count + s_length > self.max_chars and current_segment:
                segments.append(''.join(current_segment))
                current_segment = []
                char_count = 0
            
            # Check if this sentence might indicate a speaker change
            is_speaker_change = False
            if current_segment:  # Only check if we already have content
                for pattern in self.compiled_patterns:
                    if pattern.search(sentence):
                        is_speaker_change = True
                        break
            
            if is_speaker_change and current_segment:
                segments.append(''.join(current_segment))
                current_segment = []
                char_count = 0
            
            current_segment.append(sentence)
            char_count += s_length
        
        # Add the last segment if it exists
        if current_segment:
            segments.append(''.join(current_segment))
        
        return segments


class TranscriptFormatter:
    """Formats the transcript for readability"""
    
    def __init__(self):
        pass
    
    def format_time(self, seconds: float) -> str:
        """Format seconds as HH:MM:SS"""
        hours = int(seconds // 3600)
        minutes = int((seconds % 3600) // 60)
        seconds = int(seconds % 60)
        return f"{hours:02d}:{minutes:02d}:{seconds:02d}"
    
    def format_transcript(self, segments: List[Dict]) -> str:
        """Format transcript segments with timestamps"""
        formatted = []
        
        for i, segment in enumerate(segments):
            start_time = self.format_time(segment.get("start", 0))
            end_time = self.format_time(segment.get("end", 0))
            text = segment.get("text", "").strip()
            
            formatted.append(f"[{start_time} - {end_time}] {text}")
        
        return "\n\n".join(formatted)


class PostProcessor:
    """Main post-processing class that combines all processing steps"""
    
    def __init__(
        self,
        max_segment_chars: int = 500,
    ):
        self.punctuation_corrector = PunctuationCorrector()
        self.speaker_segmenter = SpeakerSegmenter(max_chars=max_segment_chars)
        self.transcript_formatter = TranscriptFormatter()
    
    def process(self, input_path: str, output_path: Optional[str] = None) -> Dict:
        """Process a transcription file and save the improved version"""
        print(f"Post-processing transcription file: {input_path}")
        
        # Load the transcription
        with open(input_path, "r", encoding="utf-8") as f:
            transcription = json.load(f)
        
        # Determine output path
        if output_path is None:
            output_path = input_path.rsplit(".", 1)[0] + ".processed.json"
        
        # Process the full text
        full_text = transcription.get("text", "")
        corrected_text = self.punctuation_corrector.correct(full_text)
        
        # Process individual segments
        processed_segments = []
        for segment in transcription.get("segments", []):
            segment_text = segment.get("text", "")
            corrected_segment = self.punctuation_corrector.correct(segment_text)
            
            processed_segment = segment.copy()
            processed_segment["text"] = corrected_segment
            processed_segments.append(processed_segment)
        
        # Create segmented version based on speaker changes
        speaker_segments = self.speaker_segmenter.segment_by_speaker(corrected_text)
        
        # Create the processed result
        processed = {
            "text": corrected_text,
            "segments": processed_segments,
            "speaker_segments": speaker_segments,
            "language": transcription.get("language", ""),
        }
        
        # Save the processed result
        with open(output_path, "w", encoding="utf-8") as f:
            json.dump(processed, f, ensure_ascii=False, indent=2)
        
        # Also save a readable text version
        text_output = output_path.rsplit(".", 1)[0] + ".txt"
        with open(text_output, "w", encoding="utf-8") as f:
            f.write(self.transcript_formatter.format_transcript(processed_segments))
            f.write("\n\n=== Speaker Segmented Version ===\n\n")
            f.write("\n\n".join(speaker_segments))
        
        print(f"Post-processing complete. Output saved to {output_path} and {text_output}")
        
        return processed


def main():
    parser = argparse.ArgumentParser(description="MeetingMinutesATS Post-processing Module")
    parser.add_argument("input_path", help="Path to the transcription JSON file")
    parser.add_argument("--output", "-o", help="Output file path (default: auto-generated)")
    parser.add_argument("--max_segment_chars", type=int, default=500, help="Maximum characters per segment (default: 500)")
    
    args = parser.parse_args()
    
    # Initialize post-processor
    post_processor = PostProcessor(
        max_segment_chars=args.max_segment_chars,
    )
    
    # Process transcription
    post_processor.process(args.input_path, args.output)


if __name__ == "__main__":
    main()
