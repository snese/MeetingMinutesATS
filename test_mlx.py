#!/usr/bin/env python3
# Test script to check MLX imports

print("Testing MLX imports...")

try:
    import mlx
    print(f"MLX version: {mlx.__version__}")
    print("MLX import successful!")
except ImportError as e:
    print(f"MLX import failed: {e}")

try:
    import mlx.core as mx
    print("MLX core import successful!")
except ImportError as e:
    print(f"MLX core import failed: {e}")

try:
    from mlx_whisper import load_model
    print("MLX Whisper import successful!")
except ImportError as e:
    print(f"MLX Whisper import failed: {e}")

print("Import test complete.")
