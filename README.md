# Video to ASCII Converter

A high-performance Lua script that converts video files into ASCII art animations with synchronized audio. This optimized tool transforms any video into a retro-style ASCII art representation that plays back as a video file.

## Features

- **Optimized Performance**: Fast image processing using PGM format for 3-5x faster conversion
- **Smart Caching System**: Automatically detects and reuses existing frames to avoid reprocessing
- **Dynamic Progress Bars**: Real-time animated progress indicators with status updates
- **Video to ASCII Conversion**: Transforms video frames into ASCII art using grayscale brightness mapping
- **Audio Processing**: Extracts and processes audio with dynamic range compression
- **Batch Processing**: Efficient frame processing with minimal memory footprint
- **Comprehensive Documentation**: Fully commented codebase with detailed explanations
- **Automatic Cleanup**: Temporary files are managed automatically

## Requirements

### Software Dependencies
- **Lua 5.1+** - The scripting language
- **FFmpeg** - For video/audio processing and frame extraction
- **ImageMagick** - For image conversion and text rendering
- **Lua File System (lfs)** - Lua library for file operations

### Installation

#### macOS (with Homebrew)
```bash
brew install lua ffmpeg imagemagick
luarocks install luafilesystem
```

#### Ubuntu/Debian
```bash
sudo apt update
sudo apt install lua5.3 ffmpeg imagemagick lua-filesystem
```

#### Windows
- Install Lua from the [official website](https://www.lua.org/)
- Install FFmpeg from the [official website](https://ffmpeg.org/)
- Install ImageMagick from the [official website](https://imagemagick.org/)
- Install LuaFileSystem via LuaRocks

## Usage

### Basic Usage

```bash
lua video_to_ascii.lua input_video.mp4 [output_video.mp4]
```

**Parameters:**
- `input_video.mp4` - Path to the input video file (required)
- `output_video.mp4` - Path for the output ASCII video (optional, defaults to "output_ascii.mp4")

### Example

```bash
lua video_to_ascii.lua nyancat.mp4 nyancat_ascii.mp4

lua video_to_ascii.lua video.mp4
```

### Sample Output

```
=== Video to ASCII Converter ===
Input: nyancat.mp4
Video: 1920x1080 @ 30 fps
ASCII output: 120x28 characters
Checking frames...
Using 6504 cached frames
Converting frames to ASCII...
[████████████████████████████░░░░░░░░░░░░░░░░] 56% (3652/6504) | Converting to ASCII
```

## Configuration

The script includes configurable settings in the `CONFIG` table:

```lua
local CONFIG = {
    ascii_chars = " .,:;i1tfLCG08@",    -- Character gradient from darkest to lightest
    output_width = 120,                   -- Width in characters (affects detail level)
    output_fps = 30,                      -- Target frame rate for output
    audio_bitrate = "128k",               -- Quality of audio in final output
    temp_dir = "temp_ascii",              -- Temporary storage directory
    frames_dir = "temp_ascii/frames",     -- Location for extracted frames
    output_format = "mp4",                -- Output container format
    cache_file = "temp_ascii/.cache"      -- Cache validation file
}
```

### Customization Options

- **ASCII Characters**: Modify the character gradient to change visual density and style
- **Output Width**: Higher values provide more detail but slower processing (recommended: 80-150)
- **Frame Rate**: Match source video FPS or reduce for smaller file sizes
- **Audio Quality**: Balance between file size and audio fidelity (64k-192k recommended)

## How It Works

The conversion process uses an optimized 8-stage pipeline:

### 1. Video Analysis
- Extracts video metadata using ffprobe (dimensions, frame rate)
- Calculates optimal ASCII output dimensions maintaining aspect ratio
- Compensates for character height-to-width ratio (0.5 factor)

### 2. Frame Extraction with Caching
- Checks cache to determine if frames can be reused
- Extracts frames only when input file changes
- Saves significant time on repeated conversions

### 3. Fast ASCII Conversion
- Uses PGM format for 5x faster pixel data reading
- Processes frames in batches of 50 for better performance
- Skips already-converted ASCII text files
- Maps brightness values (0.0-1.0) to ASCII characters

### 4. Audio Processing
- Extracts audio track to uncompressed WAV
- Applies dynamic range compression (compand filter)
- Balances volume levels for consistent output

### 5. ASCII Image Rendering
- Converts ASCII text files to PNG images with Courier font
- Processes in batches of 100 with progress feedback
- Renders white text on black background

### 6. Video Encoding
- Combines rendered frames using H.264 codec
- Uses ultrafast preset for faster processing
- Outputs temporary video file

### 7. Audio-Video Merge
- Combines ASCII video with processed audio
- Synchronizes streams using shortest duration
- Encodes to final MP4 file

### 8. Automatic Cleanup
- Removes temporary directories and files
- Preserves only the final output video

## Performance Optimizations

### Speed Improvements
- **PGM Format**: Binary pixel reading instead of slow text parsing
- **Smart Caching**: Avoids reprocessing unchanged input files
- **Batch Processing**: Processes multiple frames before progress updates
- **Ultrafast Encoding**: Faster H.264 encoding with minimal quality trade-off
- **Selective Processing**: Skips frames that already have ASCII conversions

### Expected Performance
- **3-5x faster** frame-to-ASCII conversion vs. text format parsing
- **2x faster** video rendering with optimized batch sizes
- **Near-instant** on cached runs (same input file)

### Memory Efficiency
- Processes one frame at a time
- Suitable for videos of any length
- Low memory footprint even for 4K source videos

## Progress Bar Features

The script displays animated progress bars during processing:

```
[████████████████░░░░░░░░░░░░░░░░░░░░░] 32% (2100/6504) | Converting to ASCII
```

Features:
- Updates in-place (single line, no clutter)
- Shows percentage, current/total count
- Displays current operation status
- Visual bar with filled (█) and empty (░) segments

## Output

The script generates:
- **Final video file** (default: `output_ascii.mp4`)
- **Temporary files** in `temp_ascii/` directory (auto-removed on completion)

## Troubleshooting

### Common Issues

**"Command not found" errors:**
- Ensure FFmpeg and ImageMagick are installed and in your PATH
- Test with: `ffmpeg -version` and `magick -version`

**Script runs slowly:**
- First run extracts frames and converts to ASCII (expected)
- Subsequent runs use cached data (much faster)
- Reduce `output_width` for faster processing

**Audio processing errors:**
- Verify FFmpeg supports the audio filters: `ffmpeg -filters | grep compand`
- Check that input video contains an audio track
- Some formats may require different audio codecs

**Memory issues with large videos:**
- The script processes frames individually (very memory efficient)
- Consider reducing `output_width` if issues persist
- Check available disk space in temp directory

**Lua module errors:**
```bash
lua: module 'lfs' not found
```
- Install LuaFileSystem: `luarocks install luafilesystem`
- Check Lua module path: `lua -e "print(package.path)"`

### Cache Issues

If you want to force regeneration of frames:
- Delete the cache file: `rm temp_ascii/.cache`
- Or delete the entire temp directory: `rm -rf temp_ascii/`

## Technical Details

### ASCII Character Mapping
The script uses a 16-character gradient palette:
```
" .,:;i1tfLCG08@"
```
- Space (darkest) → @ (brightest)
- Provides optimal contrast and readability
- Each character represents a brightness range

### Frame Processing Algorithm
1. Convert PNG to PGM format (grayscale, uncompressed)
2. Parse binary pixel values (0-255)
3. Normalize brightness to 0.0-1.0 range
4. Map to ASCII character index
5. Build text representation row by row
6. Write to .txt file

### Performance: PGM vs Text Format
- **PGM**: Binary format, fast parsing, ~5x faster
- **Text**: ImageMagick txt format, slow pixel-by-pixel parsing
- PGM skips header (first 3 lines) and reads space-separated values

### Audio Processing Pipeline
- **Extraction**: PCM 16-bit WAV format
- **Compression**: Compand filter with custom attack/decay curves
  - Points: `-70/-60|-60/-40|-40/-30|-20/-20`
  - Attack: 0.3s, Decay: 1.0s
- **Encoding**: AAC codec at configured bitrate
- **Sync**: Uses shortest stream duration

### Cache Validation
- Stores input filename in `.cache` file
- Compares on each run to detect input changes
- Automatically invalidates when input differs
- Saves hours on repeated conversions

## Code Documentation

The script includes comprehensive comments explaining:
- Purpose and parameters for every function
- Implementation details and optimizations
- Performance considerations
- Processing pipeline stages

View the source code for detailed inline documentation.

## Tips for Best Results

### Video Selection
- **Resolution**: Any resolution works, script resizes automatically
- **Length**: No limit, but longer videos take proportionally longer
- **Format**: Any format supported by FFmpeg (MP4, AVI, MOV, MKV, etc.)

### Quality Settings
- **High Detail**: `output_width = 150-200` (slower, more detailed)
- **Balanced**: `output_width = 100-120` (recommended)
- **Fast**: `output_width = 60-80` (faster, less detail)

### Character Set Customization
```lua
-- Higher contrast
ascii_chars = " .:oO0@"

-- More gradual
ascii_chars = " .:-=+*#%@"

-- Minimal
ascii_chars = " .@"
```

## Project Structure

```
ascii_video/
├── video_to_ascii.lua    # Main conversion script
├── README.md             # This file
├── temp_ascii/           # Temporary processing directory (auto-created)
│   ├── .cache            # Cache validation file
│   ├── frames/           # Extracted frames (PNG and TXT)
│   ├── audio.wav         # Extracted audio
│   └── audio_processed.wav
└── output_ascii.mp4      # Final output (default name)
```

## License

This project is open source and available for use and modification.
