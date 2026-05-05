extends Window

func _ready() -> void:
	# Setup theme option button first (before loading settings)
	var theme_option: OptionButton = $MarginContainer/VBoxContainer/ThemeOptionButton
	theme_option.add_item("Light")
	theme_option.add_item("Dark")
	theme_option.add_item("Auto (OS)")

	$MarginContainer/VBoxContainer/CloseButton.pressed.connect(_on_close_pressed)
	$MarginContainer/VBoxContainer/ThemeOptionButton.pressed.connect(_on_theme_selected)
	close_requested.connect(_on_close_requested)
	size = Vector2(1024, 800)

	# Now load settings (after items are added)
	load_llm_settings()
	load_theme_settings()

	# Detect screen DPI and set appropriate scale
	var dpi := DisplayServer.screen_get_dpi(0)
	var ui_scale := 2.0 if dpi > 144 else 1.0
	set_content_scale_factor(ui_scale)


func load_llm_settings() -> void:
	$MarginContainer/VBoxContainer/EndpointLineEdit.text = AppConfig.get_llm_endpoint()
	$MarginContainer/VBoxContainer/CheckEndpointLineEdit.text = AppConfig.get_llm_check_endpoint()
	$MarginContainer/VBoxContainer/ModelLineEdit.text = AppConfig.get_llm_model()
	$MarginContainer/VBoxContainer/TemperatureSpinBox.value = AppConfig.get_llm_temperature()
	$MarginContainer/VBoxContainer/MaxTokensSpinBox.value = AppConfig.get_llm_max_tokens()

func load_theme_settings() -> void:
	var theme_mode := ThemeManager.get_mode()
	var index := 0
	match theme_mode:
		ThemeManager.ThemeMode.LIGHT: index = 0
		ThemeManager.ThemeMode.DARK: index = 1
		ThemeManager.ThemeMode.AUTO: index = 2
	$MarginContainer/VBoxContainer/ThemeOptionButton.select(index)

func save_llm_settings() -> void:
	AppConfig.set_llm_endpoint($MarginContainer/VBoxContainer/EndpointLineEdit.text)
	AppConfig.set_llm_check_endpoint($MarginContainer/VBoxContainer/CheckEndpointLineEdit.text)
	AppConfig.set_llm_model($MarginContainer/VBoxContainer/ModelLineEdit.text)
	AppConfig.set_llm_temperature($MarginContainer/VBoxContainer/TemperatureSpinBox.value)
	AppConfig.set_llm_max_tokens(int($MarginContainer/VBoxContainer/MaxTokensSpinBox.value))

func save_theme_settings() -> void:
	var index = $MarginContainer/VBoxContainer/ThemeOptionButton.selected
	var theme_mode = ThemeManager.ThemeMode.LIGHT
	match index:
		0: theme_mode = ThemeManager.ThemeMode.LIGHT
		1: theme_mode = ThemeManager.ThemeMode.DARK
		2: theme_mode = ThemeManager.ThemeMode.AUTO
	ThemeManager.set_mode(theme_mode)

func _on_theme_selected() -> void:
	save_theme_settings()

func _on_close_pressed() -> void:
	save_llm_settings()
	save_theme_settings()
	EventBus.settings_closed.emit()
	queue_free()


func _on_close_requested() -> void:
	save_llm_settings()
	save_theme_settings()
	EventBus.settings_closed.emit()
	queue_free()
