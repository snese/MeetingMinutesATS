#!/usr/bin/env python3
# Quality Validation System for MeetingMinutesATS
# Tests transcription accuracy with various test cases

import os
import sys
import json
import argparse
import subprocess
import numpy as np
from pathlib import Path
from typing import Dict, List, Optional, Tuple, Union

try:
    import jiwer
except ImportError:
    print("Installing jiwer package for evaluation metrics...")
    subprocess.check_call([sys.executable, "-m", "pip", "install", "jiwer"])
    import jiwer

try:
    import sounddevice as sd
    import soundfile as sf
except ImportError:
    print("Installing sounddevice and soundfile packages for audio processing...")
    subprocess.check_call([sys.executable, "-m", "pip", "install", "sounddevice", "soundfile"])
    import sounddevice as sd
    import soundfile as sf


class TestCaseGenerator:
    """Generates test cases for transcription quality validation"""
    
    def __init__(self, output_dir: str = "../test_cases"):
        self.output_dir = output_dir
        os.makedirs(output_dir, exist_ok=True)
    
    def generate_pure_chinese_test(self, duration: int = 60, filename: str = "pure_chinese_test.wav") -> Tuple[str, str]:
        """Generate a pure Chinese test case"""
        print(f"Generating pure Chinese test case ({duration}s)...")
        
        # This would normally record or synthesize audio, but for this implementation
        # we'll just create a reference transcript and assume the audio exists
        reference_text = """
        這是一個純中文測試樣本。我們正在測試語音轉錄系統的準確性。
        系統應該能夠正確識別中文語音，包括不同的聲調和發音。
        這個測試將幫助我們評估系統在處理純中文內容時的表現。
        我們希望系統能夠達到至少95%的段落級準確率。
        """
        
        # Create reference transcript file
        output_path = os.path.join(self.output_dir, filename.replace(".wav", ".txt"))
        with open(output_path, "w", encoding="utf-8") as f:
            f.write(reference_text)
        
        # Return the audio path and reference text
        audio_path = os.path.join(self.output_dir, filename)
        return audio_path, reference_text
    
    def generate_mixed_language_test(self, duration: int = 60, filename: str = "mixed_language_test.wav") -> Tuple[str, str]:
        """Generate a mixed Chinese-English test case"""
        print(f"Generating mixed language test case ({duration}s)...")
        
        # Reference transcript with language switches
        reference_text = """
        今天我們要討論 project timeline。The deadline is next month.
        我認為我們需要 allocate more resources 來確保項目按時完成。
        According to our estimates, 我們需要再增加兩名工程師。
        The critical path includes 三個主要里程碑，每個都需要仔細規劃。
        我們應該 schedule a follow-up meeting 來追蹤進度。
        """
        
        # Create reference transcript file
        output_path = os.path.join(self.output_dir, filename.replace(".wav", ".txt"))
        with open(output_path, "w", encoding="utf-8") as f:
            f.write(reference_text)
        
        # Return the audio path and reference text
        audio_path = os.path.join(self.output_dir, filename)
        return audio_path, reference_text
    
    def generate_noisy_test(self, duration: int = 60, noise_level: float = 0.2, filename: str = "noisy_test.wav") -> Tuple[str, str]:
        """Generate a test case with background noise"""
        print(f"Generating noisy test case ({duration}s, noise level: {noise_level})...")
        
        # Reference transcript
        reference_text = """
        即使在嘈雜的環境中，系統也應該能夠識別關鍵詞和短語。
        Background noise should not significantly impact the recognition of important terms.
        會議中的重要決策和行動項目需要被準確捕捉。
        The system must maintain at least 85% keyword recognition rate in noisy environments.
        """
        
        # Create reference transcript file
        output_path = os.path.join(self.output_dir, filename.replace(".wav", ".txt"))
        with open(output_path, "w", encoding="utf-8") as f:
            f.write(reference_text)
        
        # Return the audio path and reference text
        audio_path = os.path.join(self.output_dir, filename)
        return audio_path, reference_text


class TranscriptionEvaluator:
    """Evaluates transcription quality using various metrics"""
    
    def __init__(self):
        pass
    
    def calculate_cer(self, reference: str, hypothesis: str) -> float:
        """Calculate Character Error Rate"""
        return jiwer.cer(reference, hypothesis)
    
    def calculate_wer(self, reference: str, hypothesis: str) -> float:
        """Calculate Word Error Rate"""
        return jiwer.wer(reference, hypothesis)
    
    def extract_keywords(self, reference: str, hypothesis: str) -> Dict:
        """Extract and compare keywords between reference and hypothesis"""
        # Extract important keywords from reference
        reference_words = set(reference.split())
        hypothesis_words = set(hypothesis.split())
        
        # Find keywords that are present in both
        common_words = reference_words.intersection(hypothesis_words)
        
        # Calculate keyword recognition rate
        keyword_rate = len(common_words) / len(reference_words) if reference_words else 0
        
        return {
            "keyword_recognition_rate": keyword_rate,
            "recognized_keywords": list(common_words),
            "missed_keywords": list(reference_words - hypothesis_words),
        }
    
    def evaluate_transcript(self, reference: str, hypothesis: str) -> Dict:
        """Evaluate transcription quality using multiple metrics"""
        # Clean up text for evaluation
        reference = self._clean_text(reference)
        hypothesis = self._clean_text(hypothesis)
        
        # Calculate metrics
        cer = self.calculate_cer(reference, hypothesis)
        wer = self.calculate_wer(reference, hypothesis)
        keywords = self.extract_keywords(reference, hypothesis)
        
        # Determine if the transcription meets quality standards
        meets_cer_standard = cer <= 0.05  # 5% CER threshold
        meets_wer_standard = wer <= 0.15  # 15% WER threshold
        meets_keyword_standard = keywords["keyword_recognition_rate"] >= 0.85  # 85% keyword recognition
        
        # Overall quality assessment
        overall_quality = "PASS" if (meets_cer_standard and meets_keyword_standard) else "FAIL"
        
        return {
            "cer": cer,
            "wer": wer,
            "keyword_recognition_rate": keywords["keyword_recognition_rate"],
            "recognized_keywords": keywords["recognized_keywords"],
            "missed_keywords": keywords["missed_keywords"],
            "meets_standards": {
                "cer": meets_cer_standard,
                "wer": meets_wer_standard,
                "keyword_recognition": meets_keyword_standard,
            },
            "overall_quality": overall_quality,
        }
    
    def _clean_text(self, text: str) -> str:
        """Clean text for evaluation by removing extra whitespace and normalizing"""
        # Remove extra whitespace
        text = " ".join(text.split())
        
        # Convert to lowercase for case-insensitive comparison
        text = text.lower()
        
        return text


class QualityValidator:
    """Main quality validation class that runs tests and evaluates results"""
    
    def __init__(
        self,
        transcribe_script: str = "../src/transcribe.py",
        postprocess_script: str = "../src/postprocess.py",
        output_dir: str = "../test_results",
    ):
        self.transcribe_script = transcribe_script
        self.postprocess_script = postprocess_script
        self.output_dir = output_dir
        self.test_generator = TestCaseGenerator()
        self.evaluator = TranscriptionEvaluator()
        
        os.makedirs(output_dir, exist_ok=True)
    
    def run_transcription(self, audio_path: str) -> str:
        """Run transcription on an audio file"""
        print(f"Transcribing {audio_path}...")
        
        # Run transcription script
        subprocess.run([
            sys.executable,
            self.transcribe_script,
            audio_path,
        ], check=True)
        
        # Determine output path
        base_name = os.path.basename(audio_path).rsplit(".", 1)[0]
        json_path = f"../transcriptions/{base_name}.json"
        
        # Run post-processing
        subprocess.run([
            sys.executable,
            self.postprocess_script,
            json_path,
        ], check=True)
        
        # Get the processed text output
        text_output = json_path.rsplit(".", 1)[0] + ".processed.txt"
        
        # Read the transcription
        with open(text_output, "r", encoding="utf-8") as f:
            transcription = f.read()
        
        return transcription
    
    def validate_test_case(self, audio_path: str, reference_text: str, test_name: str) -> Dict:
        """Validate a single test case"""
        print(f"Validating test case: {test_name}")
        
        # Run transcription
        transcription = self.run_transcription(audio_path)
        
        # Evaluate results
        results = self.evaluator.evaluate_transcript(reference_text, transcription)
        
        # Save results
        results_path = os.path.join(self.output_dir, f"{test_name}_results.json")
        with open(results_path, "w", encoding="utf-8") as f:
            json.dump(results, f, ensure_ascii=False, indent=2)
        
        print(f"Test case {test_name}: {results['overall_quality']}")
        print(f"  CER: {results['cer']:.2%}")
        print(f"  WER: {results['wer']:.2%}")
        print(f"  Keyword Recognition: {results['keyword_recognition_rate']:.2%}")
        
        return results
    
    def run_all_tests(self) -> Dict:
        """Run all test cases and return combined results"""
        print("Running all quality validation tests...")
        
        # Generate test cases
        pure_chinese_path, pure_chinese_ref = self.test_generator.generate_pure_chinese_test()
        mixed_lang_path, mixed_lang_ref = self.test_generator.generate_mixed_language_test()
        noisy_path, noisy_ref = self.test_generator.generate_noisy_test()
        
        # Run tests
        pure_chinese_results = self.validate_test_case(pure_chinese_path, pure_chinese_ref, "pure_chinese")
        mixed_lang_results = self.validate_test_case(mixed_lang_path, mixed_lang_ref, "mixed_language")
        noisy_results = self.validate_test_case(noisy_path, noisy_ref, "noisy")
        
        # Combine results
        all_results = {
            "pure_chinese": pure_chinese_results,
            "mixed_language": mixed_lang_results,
            "noisy": noisy_results,
            "overall_pass": all([
                pure_chinese_results["overall_quality"] == "PASS",
                mixed_lang_results["overall_quality"] == "PASS",
                noisy_results["overall_quality"] == "PASS",
            ]),
        }
        
        # Save combined results
        combined_path = os.path.join(self.output_dir, "combined_results.json")
        with open(combined_path, "w", encoding="utf-8") as f:
            json.dump(all_results, f, ensure_ascii=False, indent=2)
        
        print(f"All tests completed. Overall result: {'PASS' if all_results['overall_pass'] else 'FAIL'}")
        
        return all_results


def main():
    parser = argparse.ArgumentParser(description="MeetingMinutesATS Quality Validation System")
    parser.add_argument("--transcribe_script", default="../src/transcribe.py", help="Path to transcription script")
    parser.add_argument("--postprocess_script", default="../src/postprocess.py", help="Path to post-processing script")
    parser.add_argument("--output_dir", default="../test_results", help="Directory for test results")
    parser.add_argument("--test", choices=["all", "pure_chinese", "mixed_language", "noisy"], default="all", help="Test case to run")
    
    args = parser.parse_args()
    
    # Initialize validator
    validator = QualityValidator(
        transcribe_script=args.transcribe_script,
        postprocess_script=args.postprocess_script,
        output_dir=args.output_dir,
    )
    
    # Run specified test
    if args.test == "all":
        validator.run_all_tests()
    elif args.test == "pure_chinese":
        audio_path, reference_text = validator.test_generator.generate_pure_chinese_test()
        validator.validate_test_case(audio_path, reference_text, "pure_chinese")
    elif args.test == "mixed_language":
        audio_path, reference_text = validator.test_generator.generate_mixed_language_test()
        validator.validate_test_case(audio_path, reference_text, "mixed_language")
    elif args.test == "noisy":
        audio_path, reference_text = validator.test_generator.generate_noisy_test()
        validator.validate_test_case(audio_path, reference_text, "noisy")


if __name__ == "__main__":
    main()
