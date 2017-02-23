#!/usr/bin/env ruby

require 'subprocess'
require 'pp'

OUTPUT_DIR = "/home/dsimon/out"

def list_files(prefix)
	files_str = Subprocess.check_output(["gphoto2", "--list-files"])
	files = []
	files_str.split("\n").each do |line|
		# NOTE: Can't use gphoto index, it's unreliable
		match = /#(\d+)\s+(\S+)\s+\S+\s+(\d+) KB/.match(line)
		next unless match
		next if match[2].start_with?(".thumb")
		files.push({
			filename: match[2],
			size_kb: match[3].to_i,
			composed_name: "#{prefix}.#{match[2]}"
		})
	end
	return files
end

def download_files(prefix)
	unless File.exists?(OUTPUT_DIR)
		File.mkdir(OUTPUT_DIR)
	end

	output_pattern = File.join(OUTPUT_DIR, "#{prefix}.%f.%C")
	Subprocess.check_call([
		"gphoto2",
		"--force-overwrite",
		"--get-all-files",
		"--filename", output_pattern
	])
end

def check_files_downloaded(files)
	files.each do |file|
		path = File.join(OUTPUT_DIR, file[:composed_name])
		raise "Failed to download #{file[:filename]}" unless File.size?(path)
		real_kb = File.stat(path).size/1024.0
		diff = (file[:size_kb] - real_kb).abs
		raise "Incomplete download #{file[:filename]}" unless diff < 2.0
	end
end

def delete_files_on_camera
	Subprocess.check_call([
		"gphoto2",
		"--delete-all-files",
		"--recurse"
	])
end

def pixie_fetch
	prefix = Time.now.to_i

	begin
		files = list_files(prefix)
		if files.length == 0
			puts "Camera is empty, nothing to download."
			return
		end
		download_files(prefix)
		check_files_downloaded(files)
		puts
		puts "Files downloaded and verified, cleaning camera..."
		puts
	rescue Subprocess::NonZeroExit, RuntimeError => e
		puts "!!!! #{e.message}"
		puts
		puts "Download was not completed, leaving camera in original state."
	else
		delete_files_on_camera
		puts
		puts "Done."
	end
end

pixie_fetch
