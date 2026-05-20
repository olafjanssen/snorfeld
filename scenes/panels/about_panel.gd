extends Window

const HIGH_DPI_THRESHOLD: int = 144

func _ready():
	$Panel/VBoxContainer/VersionLabel.text = "Version: %s" % AppConfig.get_version()

	# Detect screen DPI and set appropriate scale
	var dpi: int = DisplayServer.screen_get_dpi(0)
	var ui_scale: float = 2.0 if dpi > HIGH_DPI_THRESHOLD else 1.0
	content_scale_factor = ui_scale

	# Connect window close button
	close_requested.connect(_on_close_requested)

func _on_close_requested():
	queue_free()
