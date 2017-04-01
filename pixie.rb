#!/usr/bin/env ruby

require 'subprocess'
require 'pp'

$download_dir = ARGV[0] or raise "First argument must be download dir"
$final_dir = ARGV[1] or raise "Second argument must be final dir"

$download_dir = File.expand_path($download_dir)
$final_dir = File.expand_path($final_dir)

raise "No such download dir #{$download_dir}" unless Dir.exists?($download_dir)
raise "No such final dir #{$final_dir}" unless Dir.exists?($final_dir)

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
	output_pattern = File.join($download_dir, "#{prefix}.%f.%C")
	Subprocess.check_call([
		"gphoto2",
		"--force-overwrite",
		"--get-all-files",
		"--filename", output_pattern
	])
end

def check_files_downloaded(files)
	files.each do |file|
		path = File.join($download_dir, file[:composed_name])
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

def remove_dups
	dl_paths = Dir.glob(File.join($download_dir, "*"))
	by_hash = {}
	md5cmd = "md5sum"
	if (/darwin/ =~ RUBY_PLATFORM) != nil
		md5cmd = "md5"
	end
	dl_paths.each do |dl_path|
		sum = Subprocess.check_output([md5cmd, dl_path]).split.last
		by_hash[sum] ||= []
		by_hash[sum].push dl_path
	end
	by_hash.each do |sum, paths|
		paths.drop(1).each do |dup_path|
			puts "Deleting duplicate #{dup_path}"
			File.unlink(dup_path)
		end
	end
end

def file_code_from_time(time)
	time.strftime('%F %r').gsub(':','.')
end

def file_kind(path)
	case File.extname(path).downcase
		when ".jpg", ".jpeg", ".raw", ".nef" then "Image"
		when ".mpg", ".mpeg", ".mov" then "Video"
		else "File"
	end
end

def move_files_to_final
	final_subdir_name = "Raws #{file_code_from_time(Time.now)}"
	final_subdir_path = File.join($final_dir, final_subdir_name)

	dl_paths = Dir.glob(File.join($download_dir, "*"))
	return if dl_paths.empty?
	Dir.mkdir(final_subdir_path)
	dl_paths.each do |path|
		stat = File.stat(path)
		composed_name = "#{file_kind(path)} #{file_code_from_time(stat.mtime)} #{File.basename(path)}"
		Subprocess.check_call(["mv", path, File.join(final_subdir_path, composed_name)])
	end
end

def pixie_fetch
	prefix = Time.now.to_i

	begin
		files = list_files(prefix)
		puts "Camera is empty, nothing to download." if files.length == 0
		download_files(prefix)
		check_files_downloaded(files)
	rescue Subprocess::NonZeroExit, RuntimeError => e
		puts
		puts "!!!! #{e.message}"
		puts
		puts "Download was not completed, leaving camera in original state."
		return
	else
		puts
		puts "Files verified, cleaning camera..."
		puts
		delete_files_on_camera
		puts "Checking for duplicate files..."
		remove_dups
		puts "Moving files to Unsorted Raws..."
		move_files_to_final
		puts
		puts "Done."
	end
end

pixie_fetch
