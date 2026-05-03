extends Window

func _ready() -> void:
	load_llm_settings()
	$MarginContainer/VBoxContainer/CloseButton.pressed.connect(_on_close_pressed)
	close_requested.connect(_on_close_requested)
	size = Vector2(1024, 760)

	# Detect screen DPI and set appropriate scale
	var dpi := DisplayServer.screen_get_dpi(0)
	var ui_scale := 2.0 if dpi > 144 else 1.0
	set_content_scale_factor(ui_scale)


func load_llm_settings() -> void:
	$MarginContainer/VBoxContainer/EndpointLineEdit.text = SettingsManager.get_llm_endpoint()
	$MarginContainer/VBoxContainer/CheckEndpointLineEdit.text = SettingsManager.get_llm_check_endpoint()
	$MarginContainer/VBoxContainer/ModelLineEdit.text = SettingsManager.get_llm_model()
	$MarginContainer/VBoxContainer/TemperatureSpinBox.value = SettingsManager.get_llm_temperature()
	$MarginContainer/VBoxContainer/MaxTokensSpinBox.value = SettingsManager.get_llm_max_tokens()


func save_llm_settings() -> void:
	SettingsManager.set_llm_endpoint($MarginContainer/VBoxContainer/EndpointLineEdit.text)
	SettingsManager.set_llm_check_endpoint($MarginContainer/VBoxContainer/CheckEndpointLineEdit.text)
	SettingsManager.set_llm_model($MarginContainer/VBoxContainer/ModelLineEdit.text)
	SettingsManager.set_llm_temperature($MarginContainer/VBoxContainer/TemperatureSpinBox.value)
	SettingsManager.set_llm_max_tokens(int($MarginContainer/VBoxContainer/MaxTokensSpinBox.value))


func _on_close_pressed() -> void:
	save_llm_settings()
	GlobalSignals.settings_closed.emit()
	queue_free()


func _on_close_requested() -> void:
	save_llm_settings()
	GlobalSignals.settings_closed.emit()
	queue_free()
