extends RichTextLabel

@export var default_message: String = ""
@export var display_duration: float = 2.0

var timer: Timer
var icon_text : String = "[pulse freq=1.0 color=#ffffff40 ease=-4.0]✲[/pulse] "

func _ready():
	_connect_global_signals()

	timer = Timer.new()
	timer.timeout.connect(_on_timer_timeout)
	add_child(timer)
	text = default_message

func _connect_global_signals():
	# Folder and file navigation
	GlobalSignals.folder_opened.connect(_on_folder_opened)

	# File saving
	GlobalSignals.file_saved.connect(_on_file_saved)

func _on_folder_opened(path: String):
	_set_status(icon_text + "Opened folder: %s" % path)

func _on_file_saved(path: String):
	_set_status(icon_text + "Saved: %s" % path)

func _set_status(message: String):
	text = message
	timer.start(display_duration)

func _on_timer_timeout():
	text = default_message
