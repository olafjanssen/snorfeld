extends Window

func _ready() -> void:
	Window.get_focused_window().set_content_scale_factor(2.0)
	load_llm_settings()
	$VBoxContainer/CloseButton.pressed.connect(_on_close_pressed)
	close_requested.connect(_on_close_requested)


func load_llm_settings() -> void:
	$VBoxContainer/EndpointLineEdit.text = SettingsManager.get_llm_endpoint()
	$VBoxContainer/CheckEndpointLineEdit.text = SettingsManager.get_llm_check_endpoint()
	$VBoxContainer/ModelLineEdit.text = SettingsManager.get_llm_model()
	$VBoxContainer/TemperatureSpinBox.value = SettingsManager.get_llm_temperature()
	$VBoxContainer/MaxTokensSpinBox.value = SettingsManager.get_llm_max_tokens()


func save_llm_settings() -> void:
	SettingsManager.set_llm_endpoint($VBoxContainer/EndpointLineEdit.text)
	SettingsManager.set_llm_check_endpoint($VBoxContainer/CheckEndpointLineEdit.text)
	SettingsManager.set_llm_model($VBoxContainer/ModelLineEdit.text)
	SettingsManager.set_llm_temperature($VBoxContainer/TemperatureSpinBox.value)
	SettingsManager.set_llm_max_tokens(int($VBoxContainer/MaxTokensSpinBox.value))


func _on_close_pressed() -> void:
	save_llm_settings()
	GlobalSignals.settings_closed.emit()
	queue_free()


func _on_close_requested() -> void:
	save_llm_settings()
	GlobalSignals.settings_closed.emit()
	queue_free()
