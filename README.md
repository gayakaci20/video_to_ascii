# Video to ASCII Converter

A Lua script that converts video files into ASCII art animations with synchronized audio. This tool transforms any video into a retro-style ASCII art representation that plays back as a video file.

## Features

- **Video to ASCII Conversion**: Transforms video frames into ASCII art using grayscale brightness mapping
- **Audio Processing**: Extracts, processes, and synchronizes audio with compression and equalization
- **Smart Caching**: Detects existing frames and prompts for reuse to save processing time
- **Progress Tracking**: Real-time progress bars during frame processing and video creation
- **Customizable Output**: Configurable ASCII character sets, output dimensions, and quality settings
- **Batch Processing**: Handles multiple frames efficiently with progress feedback

## Requirements

### Software Dependencies
- **Lua 5.1+** - The scripting language
- **FFmpeg** - For video/audio processing and frame extraction
- **ImageMagick** - For converting ASCII text to images
- **Lua File System (lfs)** - Lua library for file operations

### Installation

#### macOS (with Homebrew)
```bash
# Install dependencies
brew install lua ffmpeg imagemagick

# Install LuaFileSystem
luarocks install luafilesystem
```

#### Ubuntu/Debian
```bash
# Install dependencies
sudo apt update
sudo apt install lua5.3 ffmpeg imagemagick

# Install LuaFileSystem
sudo apt install lua-filesystem-dev
```

#### Windows
- Install Lua from the [official website](https://www.lua.org/)
- Install FFmpeg from the [official website](https://ffmpeg.org/)
- Install ImageMagick from the [official website](https://imagemagick.org/)
- Ensure LuaFileSystem is available (may need manual compilation)

## Usage

### Basic Usage

```bash
lua main.lua input_video.mp4 [output_video.mp4]
```

**Parameters:**
- `input_video.mp4` - Path to the input video file (required)
- `output_video.mp4` - Path for the output ASCII video (optional, defaults to "output_ascii.mp4")

### Example

```bash
# Convert a video to ASCII art
lua video_to_ascii.lua my_video.mp4 ascii_output.mp4

# Use default output filename
lua video_to_ascii.lua video.mp4
```

## Configuration

The script includes configurable settings in the `CONFIG` table:

```lua
local CONFIG = {
    ascii_chars = " .,:;i1tfLCG08@",      -- ASCII characters from dark to light
    output_width = 120,                   -- Width of ASCII output in characters
    output_fps = 30,                      -- Target frame rate for output video
    audio_bitrate = "128k",               -- Audio bitrate for final video
    temp_dir = "temp_ascii",              -- Temporary directory for processing
    frames_dir = "temp_ascii/frames",     -- Directory for extracted frames
    output_format = "mp4",                -- Output video format
}
```

### Customization Options

- **ASCII Characters**: Modify the character set to change the visual style
- **Output Dimensions**: Adjust width to control the level of detail
- **Frame Rate**: Set the playback speed of the final video
- **Audio Quality**: Configure bitrate for audio compression

## How It Works

The conversion process consists of several stages:

### 1. Video Analysis
- Extracts video metadata (dimensions, frame rate, duration)
- Calculates optimal ASCII output dimensions

### 2. Frame Extraction
- Extracts individual frames from the video as PNG images
- Prompts user to reuse existing frames if available

### 3. ASCII Conversion
- Analyzes each frame's pixel brightness
- Maps brightness values to ASCII characters
- Generates text files containing ASCII art

### 4. Audio Processing
- Extracts audio track from source video
- Applies compression and equalization filters
- Enhances audio clarity for the ASCII video

### 5. Image Generation
- Converts ASCII text files to PNG images
- Renders text with monospace font on black background
- Shows progress during batch processing

### 6. Video Creation
- Combines processed audio with ASCII images
- Encodes final video with synchronized audio
- Outputs MP4 file ready for playback

## Output

The script generates:
- **Final video file** (`output_ascii.mp4` by default)
- **Temporary files** in `temp_ascii/` directory (auto-cleaned)
- **ASCII text frames** (intermediate files, auto-cleaned)

## Performance Tips

- **Frame Reuse**: The script prompts before regenerating existing frames
- **Batch Processing**: Processes frames in batches with progress indicators
- **Memory Efficient**: Processes one frame at a time to handle large videos
- **Cleanup**: Automatically removes temporary files after completion

## Troubleshooting

### Common Issues

**"Command not found" errors:**
- Ensure FFmpeg and ImageMagick are installed and in your PATH
- Check that all dependencies are properly installed

**Audio processing errors:**
- Verify FFmpeg supports the audio filters being used
- Check that the input video has an audio track

**Memory issues with large videos:**
- The script processes frames individually, so it should handle large files
- Consider reducing `output_width` for very large source videos

**Lua module errors:**
- Ensure LuaFileSystem is properly installed
- Check Lua module search paths

### Getting Help

If you encounter issues:
1. Verify all dependencies are installed
2. Check file permissions and paths
3. Ensure input video format is supported by FFmpeg
4. Try with a small test video first

## Technical Details

### ASCII Character Mapping
The script uses a 16-character ASCII palette ranging from dark to light:
```
" .,:;i1tfLCG08@"
```
- Space (darkest) to @ (brightest)
- Provides good contrast and readability

### Frame Processing Algorithm
1. Extract grayscale pixel values from each frame
2. Normalize brightness to 0.0-1.0 range
3. Map brightness to ASCII character index
4. Generate text representation line by line

### Audio Processing Pipeline
- **Extraction**: PCM audio extraction
- **Compression**: Dynamic range compression for clarity
- **Equalization**: Frequency response optimization
- **Encoding**: AAC compression for final output

## License

This project is open source.
