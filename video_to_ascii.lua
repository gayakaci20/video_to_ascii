#!/usr/bin/env lua

local lfs = require("lfs")

local CONFIG = {
	ascii_chars = " .,:;i1tfLCG08@",
	output_width = 120,
	output_fps = 30,
	audio_bitrate = "128k",
	temp_dir = "temp_ascii",
	frames_dir = "temp_ascii/frames",
	output_format = "mp4",
	cache_file = "temp_ascii/.cache",
}

local VideoToASCII = {}
VideoToASCII.__index = VideoToASCII

function VideoToASCII:new(input_file, output_file)
	local self = setmetatable({}, VideoToASCII)
	self.input_file = input_file
	self.output_file = output_file or "output_ascii.mp4"
	self.video_info = {}
	return self
end

function VideoToASCII:create_temp_dirs()
	os.execute("mkdir -p " .. CONFIG.frames_dir)
end

function VideoToASCII:cleanup()
	os.execute("rm -rf " .. CONFIG.temp_dir)
end

function VideoToASCII:get_video_info()
	local cmd = string.format(
		"ffprobe -v error -select_streams v:0 -show_entries stream=width,height,r_frame_rate -of csv=s=x:p=0 '%s'",
		self.input_file
	)

	local handle = io.popen(cmd)
	local result = handle:read("*a")
	handle:close()

	local width, height, fps_str = result:match("(%d+)x(%d+)x([%d/]+)")

	local fps = 30
	if fps_str then
		local num, den = fps_str:match("(%d+)/(%d+)")
		if num and den then
			fps = math.floor(tonumber(num) / tonumber(den))
		end
	end

	self.video_info = {
		width = tonumber(width) or 1920,
		height = tonumber(height) or 1080,
		fps = fps,
	}

	self.video_info.output_height =
		math.floor(CONFIG.output_width * self.video_info.height / self.video_info.width * 0.5)

	print(string.format("Video: %dx%d @ %d fps", self.video_info.width, self.video_info.height, self.video_info.fps))
	print(string.format("ASCII output: %dx%d characters", CONFIG.output_width, self.video_info.output_height))
end

function VideoToASCII:display_progress_bar(current, total, status, width)
	width = width or 50
	local percent = math.floor((current / total) * 100)
	local completed = math.floor((current / total) * width)
	local remaining = width - completed
	local bar = string.rep("█", completed) .. string.rep("░", remaining)

	local status_text = status or ""
	if status_text ~= "" then
		status_text = " | " .. status_text
	end

	io.write(string.format("\r[%s] %d%% (%d/%d)%s", bar, percent, current, total, status_text))
	io.flush()

	if current >= total then
		print()
	end
end

function VideoToASCII:pixel_to_ascii(brightness)
	local index = math.floor(brightness * (#CONFIG.ascii_chars - 1)) + 1
	index = math.max(1, math.min(index, #CONFIG.ascii_chars))
	return CONFIG.ascii_chars:sub(index, index)
end

function VideoToASCII:read_png_fast(filename)
	local cmd = string.format(
		"magick '%s' -resize %dx%d! -colorspace Gray -compress none pgm:- | tail -n +4",
		filename,
		CONFIG.output_width,
		self.video_info.output_height
	)

	local handle = io.popen(cmd)
	local data = handle:read("*a")
	handle:close()

	local pixels = {}
	local idx = 1
	local byte_count = 0

	for byte_str in data:gmatch("%S+") do
		local value = tonumber(byte_str)
		if value then
			local brightness = value / 255.0
			table.insert(pixels, brightness)
			byte_count = byte_count + 1
		end
	end

	return pixels
end

function VideoToASCII:frame_to_ascii_fast(frame_path)
	local pixels = self:read_png_fast(frame_path)
	local lines = {}
	local chars_per_line = CONFIG.output_width

	for row = 0, self.video_info.output_height - 1 do
		local line_chars = {}
		for col = 1, chars_per_line do
			local idx = row * chars_per_line + col
			local brightness = pixels[idx] or 0
			table.insert(line_chars, self:pixel_to_ascii(brightness))
		end
		table.insert(lines, table.concat(line_chars))
	end

	return table.concat(lines, "\n")
end

function VideoToASCII:check_cache()
	local cache = io.open(CONFIG.cache_file, "r")
	if cache then
		local cached_input = cache:read("*l")
		cache:close()
		return cached_input == self.input_file
	end
	return false
end

function VideoToASCII:save_cache()
	local cache = io.open(CONFIG.cache_file, "w")
	if cache then
		cache:write(self.input_file .. "\n")
		cache:close()
	end
end

function VideoToASCII:extract_frames()
	print("Checking frames...")

	local frame_files = {}
	for file in lfs.dir(CONFIG.frames_dir) do
		if file:match("^frame_%d+%.png$") then
			table.insert(frame_files, file)
		end
	end

	local existing_count = #frame_files

	if existing_count > 0 and self:check_cache() then
		print(string.format("Using %d cached frames", existing_count))
		return existing_count
	end

	if existing_count > 0 then
		print("Input changed, regenerating frames...")
		os.execute("rm -f " .. CONFIG.frames_dir .. "/*.png " .. CONFIG.frames_dir .. "/*.txt")
	else
		print("Extracting frames...")
	end

	local cmd = string.format(
		"ffmpeg -i '%s' -vf 'fps=%d,scale=%d:%d' '%s/frame_%%05d.png' -hide_banner -loglevel warning",
		self.input_file,
		CONFIG.output_fps,
		CONFIG.output_width,
		self.video_info.output_height,
		CONFIG.frames_dir
	)

	os.execute(cmd)

	local count = 0
	for file in lfs.dir(CONFIG.frames_dir) do
		if file:match("%.png$") then
			count = count + 1
		end
	end

	print(string.format("Frames extracted: %d", count))
	self:save_cache()
	return count
end

function VideoToASCII:process_frames_batch()
	print("Converting frames to ASCII...")

	local png_files = {}
	for file in lfs.dir(CONFIG.frames_dir) do
		if file:match("^frame_%d+%.png$") then
			table.insert(png_files, file)
		end
	end

	table.sort(png_files)

	if #png_files == 0 then
		print("No frames found")
		return 0
	end

	local txt_count = 0
	for file in lfs.dir(CONFIG.frames_dir) do
		if file:match("^frame_%d+%.txt$") then
			txt_count = txt_count + 1
		end
	end

	if txt_count == #png_files then
		print(string.format("All %d ASCII frames exist", txt_count))
		return txt_count
	end

	local batch_size = 50
	local processed = 0

	for i = 1, #png_files, batch_size do
		local batch_end = math.min(i + batch_size - 1, #png_files)

		for j = i, batch_end do
			local file = png_files[j]
			local txt_file = file:gsub("%.png$", ".txt")
			local txt_path = CONFIG.frames_dir .. "/" .. txt_file

			local exists = io.open(txt_path, "r")
			if exists then
				exists:close()
			else
				local frame_path = CONFIG.frames_dir .. "/" .. file
				local ascii_frame = self:frame_to_ascii_fast(frame_path)

				local out = io.open(txt_path, "w")
				out:write(ascii_frame)
				out:close()

				processed = processed + 1
			end
		end

		self:display_progress_bar(batch_end, #png_files, "Converting to ASCII")
	end

	print(string.format("Converted %d new frames", processed))
	return #png_files
end

function VideoToASCII:process_audio()
	print("Processing audio...")

	local audio_file = CONFIG.temp_dir .. "/audio.wav"
	local cmd = string.format(
		"ffmpeg -i '%s' -vn -acodec pcm_s16le '%s' -hide_banner -loglevel error -y",
		self.input_file,
		audio_file
	)
	os.execute(cmd)

	local processed_audio = CONFIG.temp_dir .. "/audio_processed.wav"
	cmd = string.format(
		"ffmpeg -i '%s' -af 'compand=attacks=0.3:decays=1.0:points=-70/-60|-60/-40|-40/-30|-20/-20' '%s' -hide_banner -loglevel error -y",
		audio_file,
		processed_audio
	)
	os.execute(cmd)

	print("Audio processed")
	return processed_audio
end

function VideoToASCII:create_ascii_video_fast()
	print("Creating ASCII video...")

	local txt_files = {}
	for file in lfs.dir(CONFIG.frames_dir) do
		if file:match("^frame_%d+%.txt$") then
			table.insert(txt_files, file)
		end
	end

	table.sort(txt_files)

	if #txt_files == 0 then
		print("No ASCII frames found")
		return
	end

	print(string.format("Rendering %d ASCII frames to images...", #txt_files))

	local batch_size = 100
	for i = 1, #txt_files, batch_size do
		local batch_end = math.min(i + batch_size - 1, #txt_files)

		for j = i, batch_end do
			local file = txt_files[j]
			local txt_path = CONFIG.frames_dir .. "/" .. file
			local png_path = txt_path:gsub("%.txt$", "_ascii.png")

			local cmd = string.format(
				"magick -size %dx%d xc:black -font Courier -pointsize 10 -fill white -annotate +5+15 @'%s' '%s' 2>/dev/null",
				self.video_info.width,
				self.video_info.height,
				txt_path,
				png_path
			)
			os.execute(cmd)
		end

		self:display_progress_bar(batch_end, #txt_files, "Rendering ASCII frames")
	end

	print("Encoding video from images...")

	local cmd = string.format(
		"ffmpeg -framerate %d -pattern_type glob -i '%s/*_ascii.png' -c:v libx264 -preset ultrafast -pix_fmt yuv420p '%s/video_temp.mp4' -hide_banner -loglevel error -y",
		CONFIG.output_fps,
		CONFIG.frames_dir,
		CONFIG.temp_dir
	)
	os.execute(cmd)

	print("Video created")
end

function VideoToASCII:combine_video_audio(audio_file)
	print("Combining video and audio...")

	local cmd = string.format(
		"ffmpeg -i '%s/video_temp.mp4' -i '%s' -c:v copy -c:a aac -b:a %s -shortest '%s' -hide_banner -loglevel error -y",
		CONFIG.temp_dir,
		audio_file,
		CONFIG.audio_bitrate,
		self.output_file
	)

	os.execute(cmd)
	print(string.format("Output: %s", self.output_file))
end

function VideoToASCII:convert()
	print("- Video to ASCII Converter -")
	print(string.format("Input: %s", self.input_file))

	local file = io.open(self.input_file, "r")
	if not file then
		print("Error: File not found")
		return false
	end
	file:close()

	self:create_temp_dirs()
	self:get_video_info()
	self:extract_frames()
	self:process_frames_batch()

	local audio_file = self:process_audio()
	self:create_ascii_video_fast()
	self:combine_video_audio(audio_file)

	print("Completed")
	return true
end

function main(args)
	if #args < 1 then
		print("Usage: lua video_to_ascii.lua <input_video> [output_video]")
		return
	end

	local input_file = args[1]
	local output_file = args[2]

	local converter = VideoToASCII:new(input_file, output_file)
	converter:convert()
end

main(arg)

