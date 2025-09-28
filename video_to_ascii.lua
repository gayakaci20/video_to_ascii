#!/usr/bin/env lua

-- Video to ASCII Converter with Audio Processing
-- Converts video files to ASCII art animations with synchronized audio

local lfs = require("lfs")

-- Configuration settings for the ASCII conversion process
local CONFIG = {
	ascii_chars = " .,:;i1tfLCG08@",      -- ASCII characters from dark to light
	output_width = 120,                   -- Width of ASCII output in characters
	output_fps = 30,                      -- Target frame rate for output video
	audio_bitrate = "128k",               -- Audio bitrate for final video
	temp_dir = "temp_ascii",              -- Temporary directory for processing
	frames_dir = "temp_ascii/frames",     -- Directory for extracted frames
	output_format = "mp4",                -- Output video format
}

-- VideoToASCII class for converting videos to ASCII art
local VideoToASCII = {}
VideoToASCII.__index = VideoToASCII

-- Constructor: Creates a new VideoToASCII instance
-- @param input_file: Path to the input video file
-- @param output_file: Path for the output ASCII video (optional, defaults to "output_ascii.mp4")
function VideoToASCII:new(input_file, output_file)
	local self = setmetatable({}, VideoToASCII)
	self.input_file = input_file
	self.output_file = output_file or "output_ascii.mp4"
	self.video_info = {}
	return self
end

-- Creates necessary temporary directories for processing
function VideoToASCII:create_temp_dirs()
	os.execute("mkdir -p " .. CONFIG.frames_dir)
end

-- Cleans up temporary files and directories after processing
function VideoToASCII:cleanup()
	os.execute("rm -rf " .. CONFIG.temp_dir)
end

-- Extracts video metadata (dimensions, frame rate) using ffprobe
function VideoToASCII:get_video_info()
	-- Use ffprobe to get video stream information
	local cmd = string.format(
		"ffprobe -v error -select_streams v:0 -show_entries stream=width,height,r_frame_rate,duration -of csv=s=x:p=0 '%s'",
		self.input_file
	)

	local handle = io.popen(cmd)
	local result = handle:read("*a")
	handle:close()

	-- Parse the ffprobe output to extract width, height, and frame rate
	local width, height, fps = result:match("(%d+)x(%d+)x([%d%.]+)")

	-- Store video information with fallback defaults
	self.video_info = {
		width = tonumber(width) or 1920,
		height = tonumber(height) or 1080,
		fps = tonumber(fps) or 30,
	}

	-- Calculate output height maintaining aspect ratio (0.5 factor for character aspect ratio)
	self.video_info.output_height =
		math.floor(CONFIG.output_width * self.video_info.height / self.video_info.width * 0.5)

	print(string.format("Video: %dx%d @ %d fps", self.video_info.width, self.video_info.height, self.video_info.fps))
	print(string.format("ASCII output: %dx%d characters", CONFIG.output_width, self.video_info.output_height))
end

-- Counts existing PNG frame files in the frames directory
function VideoToASCII:check_existing_frames()
	local count = 0
	for file in lfs.dir(CONFIG.frames_dir) do
		if file:match("^frame_%d+%.png$") then
			count = count + 1
		end
	end
	return count
end

-- Extracts frames from video or reuses existing frames
-- Prompts user to reuse existing frames to save processing time
function VideoToASCII:extract_frames()
	print("Extracting frames...")

	local existing_count = self:check_existing_frames()

	if existing_count > 0 then
		print(string.format("%d existing frames found", existing_count))
		io.write("Do you want to reuse them (y/n)? ")
		local response = io.read()

		-- Accept both English and French responses for compatibility
		if response and (response:lower() == "y" or response:lower() == "yes" or response:lower() == "o" or response:lower() == "oui") then
			print(string.format("Using %d existing frames", existing_count))
			return existing_count
		else
			print("Regenerating frames...")
			os.execute("rm -f " .. CONFIG.frames_dir .. "/frame_*.png")
		end
	end

	-- Extract frames using ffmpeg with specified dimensions and frame rate
	local cmd = string.format(
		"ffmpeg -i '%s' -vf 'fps=%d,scale=%d:%d' '%s/frame_%%05d.png' -hide_banner -loglevel error",
		self.input_file,
		CONFIG.output_fps,
		CONFIG.output_width,
		self.video_info.output_height,
		CONFIG.frames_dir
	)

	os.execute(cmd)

	-- Count the extracted frames
	local count = 0
	for file in lfs.dir(CONFIG.frames_dir) do
		if file:match("%.png$") then
			count = count + 1
		end
	end

	print(string.format("Frames extracted: %d", count))
	return count
end

-- Converts pixel brightness (0.0 to 1.0) to appropriate ASCII character
-- @param brightness: Normalized brightness value (0.0 = black, 1.0 = white)
-- @return: Single ASCII character representing the brightness level
function VideoToASCII:pixel_to_ascii(brightness)
	-- Map brightness to ASCII character index
	local index = math.floor(brightness * (#CONFIG.ascii_chars - 1)) + 1
	-- Ensure index is within valid range
	index = math.max(1, math.min(index, #CONFIG.ascii_chars))
	return CONFIG.ascii_chars:sub(index, index)
end

-- Reads PNG file and extracts grayscale pixel data using ImageMagick
-- @param filename: Path to the PNG file to read
-- @return: 2D table of normalized brightness values (0.0 to 1.0)
function VideoToASCII:read_png_grayscale(filename)
	-- Use ImageMagick to convert image to grayscale text format
	local cmd = string.format("magick '%s' -colorspace Gray -depth 8 txt:- | grep -v '^#'", filename)

	local handle = io.popen(cmd)
	local pixels = {}

	-- Parse ImageMagick's text output format
	for line in handle:lines() do
		-- Match pattern: "x,y: (gray_value)"
		local x, y, gray = line:match("(%d+),(%d+):%s*%((%d+)")
		if x and y and gray then
			x, y, gray = tonumber(x), tonumber(y), tonumber(gray)
			-- Create 2D array structure for pixels
			if not pixels[y] then
				pixels[y] = {}
			end
			-- Normalize gray value to 0.0-1.0 range
			pixels[y][x] = gray / 255.0
		end
	end

	handle:close()
	return pixels
end

-- Converts a PNG frame to ASCII art text representation
-- @param frame_path: Path to the PNG frame file
-- @return: Multi-line string containing ASCII art representation
function VideoToASCII:frame_to_ascii(frame_path)
	local pixels = self:read_png_grayscale(frame_path)
	local ascii_frame = {}

	-- Process each row of the output
	for y = 0, self.video_info.output_height - 1 do
		local line = {}
		-- Process each column of the output
		for x = 0, CONFIG.output_width - 1 do
			-- Get brightness value, default to black if pixel doesn't exist
			local brightness = pixels[y] and pixels[y][x] or 0
			table.insert(line, self:pixel_to_ascii(brightness))
		end
		-- Join characters in this row and add to frame
		table.insert(ascii_frame, table.concat(line))
	end

	-- Join all rows with newlines
	return table.concat(ascii_frame, "\n")
end

-- Counts existing ASCII text frame files in the frames directory
function VideoToASCII:check_existing_ascii_frames()
	local count = 0
	for file in lfs.dir(CONFIG.frames_dir) do
		if file:match("^frame_%d+%.txt$") then
			count = count + 1
		end
	end
	return count
end

-- Converts PNG frames to ASCII text files, skipping existing files
-- Only processes frames that haven't been converted yet to save time
function VideoToASCII:process_frames()
	print("Converting frames to ASCII...")

	local existing_ascii_count = self:check_existing_ascii_frames()
	local total_png_count = self:check_existing_frames()

	-- If all ASCII frames already exist, no need to process further
	if existing_ascii_count == total_png_count and total_png_count > 0 then
		print(string.format("All %d ASCII frames already exist", existing_ascii_count))
		return existing_ascii_count
	end

	-- Report progress if some frames already exist
	if existing_ascii_count > 0 then
		print(string.format("%d ASCII frames already exist, converting %d missing frames...", existing_ascii_count, total_png_count - existing_ascii_count))
	end

	local frame_count = 0

	-- Process each PNG frame file
	for file in lfs.dir(CONFIG.frames_dir) do
		if file:match("^frame_%d+%.png$") then
			local ascii_file = file:gsub("%.png$", ".txt")
			local ascii_path = CONFIG.frames_dir .. "/" .. ascii_file

			-- Check if ASCII file already exists
			local ascii_exists = false
			local test_file = io.open(ascii_path, "r")
			if test_file then
				test_file:close()
				ascii_exists = true
			end

			-- Only convert if ASCII file doesn't exist
			if not ascii_exists then
				frame_count = frame_count + 1
				local frame_path = CONFIG.frames_dir .. "/" .. file
				local ascii_frame = self:frame_to_ascii(frame_path)

				-- Write ASCII art to text file
				local file_handle = io.open(ascii_path, "w")
				file_handle:write(ascii_frame)
				file_handle:close()
			end

			-- Show progress every 10 frames
			if frame_count % 10 == 0 then
				print(string.format("Frames processed: %d", frame_count))
			end
		end
	end

	print(string.format("Total frames converted: %d", frame_count))
	return frame_count
end

-- Extracts audio from video and applies compression and equalization filters
-- @return: Path to the processed audio file
function VideoToASCII:process_audio()
	print("Extracting and processing audio...")

	-- Extract raw audio from video file
	local audio_file = CONFIG.temp_dir .. "/audio.wav"
	local cmd = string.format(
		"ffmpeg -i '%s' -vn -acodec pcm_s16le '%s' -hide_banner -loglevel error",
		self.input_file,
		audio_file
	)
	os.execute(cmd)

	-- Apply audio processing filters: dynamic range compression and equalization
	local processed_audio = CONFIG.temp_dir .. "/audio_processed.wav"
	cmd = string.format(
		"ffmpeg -i '%s' -af 'compand=attacks=0.3:decays=1.0:points=-70/-60|-60/-40|-40/-30|-20/-20,equalizer=f=100:width_type=h:width=200:g=-5,equalizer=f=3000:width_type=h:width=200:g=3' '%s' -hide_banner -loglevel error",
		audio_file,
		processed_audio
	)
	os.execute(cmd)

	print("Audio processed with compression and equalization")
	return processed_audio
end

-- Displays a progress bar with percentage and completion status
-- @param current: Current progress count
-- @param total: Total count to reach
-- @param prefix: Text to display before the progress bar
function VideoToASCII:print_progress(current, total, prefix)
	local percentage = math.floor((current / total) * 100)
	local progress_chars = math.floor((current / total) * 50)
	local bar = string.rep("=", progress_chars) .. string.rep(" ", 50 - progress_chars)

	if current < total then
		-- Update progress bar in place
		io.write(string.format("\r%s [%s] %d/%d (%d%%)", prefix, bar, current, total, percentage))
		io.flush()
	else
		-- Final progress display on new line
		print(string.format("\r%s [%s] %d/%d (%d%%)", prefix, bar, current, total, percentage))
	end
end

-- Creates ASCII video by converting text files to images and then to video
-- Two-step process: 1) Convert ASCII text to PNG images, 2) Combine images into video
function VideoToASCII:create_ascii_video()
	print("Creating ASCII video...")

	-- Prepare ffmpeg filter for creating black background video
	local filter_complex = string.format(
		"color=black:s=%dx%d:r=%d[base]",
		self.video_info.width,
		self.video_info.height,
		CONFIG.output_fps
	)

	-- Count total ASCII text frames to process
	local total_frames = 0
	for file in lfs.dir(CONFIG.frames_dir) do
		if file:match("^frame_%d+%.txt$") then
			total_frames = total_frames + 1
		end
	end

	if total_frames == 0 then
		print("No ASCII frames found to process")
		return
	end

	print(string.format("Processing %d frames...", total_frames))

	local processed_count = 0

	-- Step 1: Convert each ASCII text file to PNG image using ImageMagick
	for file in lfs.dir(CONFIG.frames_dir) do
		if file:match("^frame_%d+%.txt$") then
			processed_count = processed_count + 1
			local txt_path = CONFIG.frames_dir .. "/" .. file
			local png_path = txt_path:gsub("%.txt$", "_ascii.png")

			-- Use ImageMagick to render ASCII text as white text on black background
			local cmd = string.format(
				"magick -size %dx%d xc:black -font 'Courier' -pointsize 10 -fill white -annotate +0+10 @'%s' '%s'",
				self.video_info.width,
				self.video_info.height,
				txt_path,
				png_path
			)
			os.execute(cmd)

			-- Show progress bar during conversion
			self:print_progress(processed_count, total_frames, "Progress")
		end
	end

	print("\nCreating video from images...")

	-- Step 2: Use ffmpeg to combine all PNG images into a video file
	local cmd = string.format(
		"ffmpeg -framerate %d -pattern_type glob -i '%s/*_ascii.png' -c:v libx264 -pix_fmt yuv420p '%s/video_temp.mp4' -hide_banner -loglevel error",
		CONFIG.output_fps,
		CONFIG.frames_dir,
		CONFIG.temp_dir
	)
	os.execute(cmd)

	print("ASCII video created")
end

-- Combines the ASCII video with the processed audio to create the final output
-- @param audio_file: Path to the processed audio file
function VideoToASCII:combine_video_audio(audio_file)
	print("Combining video and audio...")

	-- Use ffmpeg to merge video and audio streams
	local cmd = string.format(
		"ffmpeg -i '%s/video_temp.mp4' -i '%s' -c:v copy -c:a aac -b:a %s -shortest '%s' -hide_banner -loglevel error",
		CONFIG.temp_dir,
		audio_file,
		CONFIG.audio_bitrate,
		self.output_file
	)

	os.execute(cmd)
	print(string.format("Final video saved: %s", self.output_file))
end

-- Main conversion function that orchestrates the entire video-to-ASCII process
-- @return: true if conversion successful, false otherwise
function VideoToASCII:convert()
	print("=== Video to ASCII Conversion ===")
	print(string.format("Source file: %s", self.input_file))

	-- Validate input file exists
	local file = io.open(self.input_file, "r")
	if not file then
		print("Error: File not found!")
		return false
	end
	file:close()

	-- Execute conversion pipeline step by step
	self:create_temp_dirs()
	self:get_video_info()
	self:extract_frames()
	self:process_frames()

	local audio_file = self:process_audio()
	self:create_ascii_video()
	self:combine_video_audio(audio_file)

	self:cleanup()

	print("=== Conversion completed! ===")
	return true
end

-- Main entry point for the video to ASCII converter
-- @param args: Command line arguments (input file and optional output file)
function main(args)
	-- Validate command line arguments
	if #args < 1 then
		print("Usage: lua video_to_ascii.lua <input_video> [output_video]")
		print("Example: lua video_to_ascii.lua input.mp4 output_ascii.mp4")
		return
	end

	-- Extract input and output file paths from arguments
	local input_file = args[1]
	local output_file = args[2]

	-- Create converter instance and start conversion process
	local converter = VideoToASCII:new(input_file, output_file)
	converter:convert()
end

main(arg)
