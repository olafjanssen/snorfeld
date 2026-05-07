extends Node
## ThemeManager - Manages theme switching between light/dark modes

# Theme mode enum
enum ThemeMode {
	LIGHT,
	DARK,
	AUTO
}

# Config file
const CONFIG_FILE := "user://theme_settings.cfg"

# Theme resources
const LIGHT_THEME := preload("res://themes/light.tres")
const DARK_THEME := preload("res://themes/dark.tres")

# Current mode
var _current_mode: ThemeMode = ThemeMode.AUTO

# Timer for checking OS theme changes
var _check_timer: Timer

const OS_THEME_CHECK_INTERVAL: float = 5.0

func _ready() -> void:
	# Load saved mode from config
	var config := ConfigFile.new()
	if config.load(CONFIG_FILE) == OK:
		var mode_str: String = config.get_value("theme", "mode", "auto")
		match mode_str:
			"light": _current_mode = ThemeMode.LIGHT
			"dark": _current_mode = ThemeMode.DARK
			_: _current_mode = ThemeMode.AUTO
	else:
		_current_mode = ThemeMode.AUTO

	# Apply initial theme
	apply_theme()

	# Set up OS theme change detection
	_check_timer = Timer.new()
	_check_timer.timeout.connect(_on_check_timer_timeout)
	_check_timer.timeout.connect(_check_os_theme_change)
	add_child(_check_timer)
	_check_timer.start(OS_THEME_CHECK_INTERVAL)  # Check every few seconds

func _on_check_timer_timeout() -> void:
	_check_timer.start(OS_THEME_CHECK_INTERVAL)

func _check_os_theme_change() -> void:
	if _current_mode == ThemeMode.AUTO:
		var is_dark := DisplayServer.is_dark_mode()
		var current_theme_is_dark := get_tree().root.get_theme() == DARK_THEME
		if is_dark != current_theme_is_dark:
			apply_theme()

# Apply the current theme based on mode
func apply_theme() -> void:
	var theme: Theme
	match _current_mode:
		ThemeMode.LIGHT:
			theme = LIGHT_THEME
		ThemeMode.DARK:
			theme = DARK_THEME
		ThemeMode.AUTO:
			theme = DARK_THEME if DisplayServer.is_dark_mode() else LIGHT_THEME
	get_tree().root.set_theme(theme)
	EventBus.theme_changed.emit()

# Set theme mode
func set_mode(mode: ThemeMode) -> void:
	_current_mode = mode
	apply_theme()
	save_settings()

# Get current mode
func get_mode() -> ThemeMode:
	return _current_mode

# Save settings
func save_settings() -> void:
	var config := ConfigFile.new()
	var mode_str := ""
	match _current_mode:
		ThemeMode.LIGHT: mode_str = "light"
		ThemeMode.DARK: mode_str = "dark"
		ThemeMode.AUTO: mode_str = "auto"
	config.set_value("theme", "mode", mode_str)
	config.save(CONFIG_FILE)
