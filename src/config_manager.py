#!/usr/bin/env python3
# Configuration Manager for MeetingMinutesATS
# Handles loading, saving, and accessing configuration settings

import os
import json
import argparse
from typing import Dict, Any, Optional

# Default configuration file path
DEFAULT_CONFIG_PATH = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 
                                  "config", "default_config.json")

class ConfigManager:
    """Manages configuration settings for MeetingMinutesATS"""
    
    def __init__(self, config_path: Optional[str] = None):
        """Initialize the configuration manager"""
        self.config_path = config_path or DEFAULT_CONFIG_PATH
        self.config = self.load_config()
    
    def load_config(self) -> Dict[str, Any]:
        """Load configuration from file"""
        try:
            if os.path.exists(self.config_path):
                with open(self.config_path, "r", encoding="utf-8") as f:
                    return json.load(f)
            else:
                print(f"Configuration file not found at {self.config_path}")
                print("Creating default configuration...")
                return self._create_default_config()
        except Exception as e:
            print(f"Error loading configuration: {e}")
            print("Using default configuration...")
            return self._create_default_config()
    
    def save_config(self, config_path: Optional[str] = None) -> None:
        """Save configuration to file"""
        save_path = config_path or self.config_path
        
        # Create directory if it doesn't exist
        os.makedirs(os.path.dirname(save_path), exist_ok=True)
        
        try:
            with open(save_path, "w", encoding="utf-8") as f:
                json.dump(self.config, f, ensure_ascii=False, indent=2)
            print(f"Configuration saved to {save_path}")
        except Exception as e:
            print(f"Error saving configuration: {e}")
    
    def get(self, section: str, key: str, default: Any = None) -> Any:
        """Get a configuration value"""
        try:
            return self.config[section][key]
        except (KeyError, TypeError):
            return default
    
    def set(self, section: str, key: str, value: Any) -> None:
        """Set a configuration value"""
        if section not in self.config:
            self.config[section] = {}
        self.config[section][key] = value
    
    def get_section(self, section: str) -> Dict[str, Any]:
        """Get an entire configuration section"""
        return self.config.get(section, {})
    
    def _create_default_config(self) -> Dict[str, Any]:
        """Create default configuration"""
        default_config = {
            "transcription": {
                "model": "large-v3",
                "quant": "q4_0",
                "language": "zh-tw",
                "beam_size": 5,
                "temperature": 0.2,
                "initial_prompt": "會議語言:繁體中文70%,英文30%",
                "chunk_size": 300
            },
            "post_processing": {
                "max_segment_chars": 500,
                "enable_speaker_segmentation": True,
                "enable_punctuation_correction": True
            },
            "system": {
                "memory_limit": 0.75,
                "max_processes": 2,
                "output_dir": "transcriptions",
                "recordings_dir": "recordings",
                "logs_dir": "logs"
            },
            "monitoring": {
                "memory_threshold": 14,
                "consecutive_threshold": 3,
                "check_interval": 300
            },
            "fallback": {
                "model": "medium-q8",
                "beam_size": 3,
                "chunk_size": 180,
                "memory_limit": 0.6
            }
        }
        
        # Save the default configuration
        self.config = default_config
        self.save_config()
        
        return default_config


def main():
    """Command-line interface for the configuration manager"""
    parser = argparse.ArgumentParser(description="MeetingMinutesATS Configuration Manager")
    parser.add_argument("--config", help="Path to configuration file")
    parser.add_argument("--get", nargs=2, metavar=("SECTION", "KEY"), help="Get a configuration value")
    parser.add_argument("--set", nargs=3, metavar=("SECTION", "KEY", "VALUE"), help="Set a configuration value")
    parser.add_argument("--show", action="store_true", help="Show the entire configuration")
    parser.add_argument("--reset", action="store_true", help="Reset to default configuration")
    
    args = parser.parse_args()
    
    # Initialize configuration manager
    config_manager = ConfigManager(args.config)
    
    # Process commands
    if args.get:
        section, key = args.get
        value = config_manager.get(section, key)
        print(f"{section}.{key} = {value}")
    
    elif args.set:
        section, key, value = args.set
        
        # Try to convert value to appropriate type
        try:
            # Try as number
            if value.lower() == "true":
                typed_value = True
            elif value.lower() == "false":
                typed_value = False
            elif "." in value:
                typed_value = float(value)
            else:
                typed_value = int(value)
        except (ValueError, AttributeError):
            # Keep as string
            typed_value = value
        
        config_manager.set(section, key, typed_value)
        config_manager.save_config()
        print(f"Set {section}.{key} = {typed_value}")
    
    elif args.show:
        print(json.dumps(config_manager.config, ensure_ascii=False, indent=2))
    
    elif args.reset:
        config_manager._create_default_config()
        print("Configuration reset to defaults")
    
    else:
        # Show usage if no arguments provided
        parser.print_help()


if __name__ == "__main__":
    main()
