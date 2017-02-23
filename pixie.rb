#!/usr/bin/env ruby

require 'fox16'
require 'gphoto2'
require 'pp'

include Fox

def find_files_recursive(folder)
	folder.files + folder.folders.map{|f2| find_files_recursive(f2) }.flatten(1)
end

def fetch_camera_data
	GPhoto2::Camera.first do |camera|
		yield "Connected, scanning files..."
		files = find_files_recursive(camera.filesystem)
	end
rescue RuntimeError => e
	if e.message.include?("no devices detected")
		yield "No devices detected"
	else
		raise e
	end
end

fetch_camera_data do |msg|
	puts msg
end

exit

app = FXApp.new

main_win = FXMainWindow.new(
	app,
	"Pixie Fetch", 
	width: 300,
	height: 80,
	opts: DECOR_BORDER + DECOR_TITLE,
	padTop: 20,
	padLeft: 10,
	padRight: 10
)

status = FXLabel.new(main_win, " ")

btn_matrix = FXMatrix.new(main_win, 2, opts: MATRIX_BY_COLUMNS, hSpacing: 20)

download_btn = FXButton.new(btn_matrix, "Download", padLeft: 10, padRight: 10)
download_btn.connect(SEL_COMMAND) do
	fetch_camera_data do |msg|
		status.text = msg
	end
end

close_btn = FXButton.new(btn_matrix, "Quit", padLeft: 10, padRight: 10)
close_btn.connect(SEL_COMMAND) do
	exit
end

main_win.show
app.create
app.run
