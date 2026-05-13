extends Window

const DEFAULT_WINDOW_SIZE: Vector2 = Vector2(1024, 800)
const DPI_THRESHOLD: int = 144

func _ready() -> void:
	# Setup theme option button first (before loading settings)
	var theme_option: OptionButton = $ScrollContainer/MarginContainer/VBoxContainer/ThemeOptionButton
	theme_option.add_item("Light")
	theme_option.add_item("Dark")
	theme_option.add_item("Auto (OS)")

	$ScrollContainer/MarginContainer/VBoxContainer/CloseButton.pressed.connect(_on_close_pressed)
	$ScrollContainer/MarginContainer/VBoxContainer/ThemeOptionButton.pressed.connect(_on_theme_selected)
	close_requested.connect(_on_close_requested)
	size = DEFAULT_WINDOW_SIZE

	# Now load settings (after items are added)
	load_llm_settings()
	load_theme_settings()
	load_editor_settings()
	load_cache_settings()

	# Detect screen DPI and set appropriate scale
	var dpi := DisplayServer.screen_get_dpi(0)
	var ui_scale := 2.0 if dpi > DPI_THRESHOLD else 1.0
	set_content_scale_factor(ui_scale)


func load_llm_settings() -> void:
	$ScrollContainer/MarginContainer/VBoxContainer/EndpointLineEdit.text = AppConfig.get_llm_endpoint()
	$ScrollContainer/MarginContainer/VBoxContainer/CheckEndpointLineEdit.text = AppConfig.get_llm_check_endpoint()
	$ScrollContainer/MarginContainer/VBoxContainer/ModelLineEdit.text = AppConfig.get_llm_model()
	$ScrollContainer/MarginContainer/VBoxContainer/TemperatureSpinBox.value = AppConfig.get_llm_temperature()
	$ScrollContainer/MarginContainer/VBoxContainer/MaxTokensSpinBox.value = AppConfig.get_llm_max_tokens()
	$ScrollContainer/MarginContainer/VBoxContainer/EmbeddingEndpointLineEdit.text = AppConfig.get_embedding_endpoint()
	$ScrollContainer/MarginContainer/VBoxContainer/EmbeddingModelLineEdit.text = AppConfig.get_embedding_model()

func load_cache_settings() -> void:
	var checkbox : CheckBox = $ScrollContainer/MarginContainer/VBoxContainer/CacheLocationCheckBox
	checkbox.button_pressed = AppConfig.get_cache_location() == "global"

func load_theme_settings() -> void:
	var theme_mode: ThemeManager.ThemeMode = ThemeManager.get_mode()
	var index: int = 0
	match theme_mode:
		ThemeManager.ThemeMode.LIGHT: index = 0
		ThemeManager.ThemeMode.DARK: index = 1
		ThemeManager.ThemeMode.AUTO: index = 2
	$ScrollContainer/MarginContainer/VBoxContainer/ThemeOptionButton.select(index)

func load_editor_settings() -> void:
	$ScrollContainer/MarginContainer/VBoxContainer/LineLengthSpinBox.value = AppConfig.get_editor_line_length()

func save_llm_settings() -> void:
	AppConfig.set_llm_endpoint($ScrollContainer/MarginContainer/VBoxContainer/EndpointLineEdit.text)
	AppConfig.set_llm_check_endpoint($ScrollContainer/MarginContainer/VBoxContainer/CheckEndpointLineEdit.text)
	AppConfig.set_llm_model($ScrollContainer/MarginContainer/VBoxContainer/ModelLineEdit.text)
	AppConfig.set_llm_temperature($ScrollContainer/MarginContainer/VBoxContainer/TemperatureSpinBox.value)
	AppConfig.set_llm_max_tokens(int($ScrollContainer/MarginContainer/VBoxContainer/MaxTokensSpinBox.value))
	AppConfig.set_embedding_endpoint($ScrollContainer/MarginContainer/VBoxContainer/EmbeddingEndpointLineEdit.text)
	AppConfig.set_embedding_model($ScrollContainer/MarginContainer/VBoxContainer/EmbeddingModelLineEdit.text)

func save_cache_settings() -> void:
	var checkbox : CheckBox = $ScrollContainer/MarginContainer/VBoxContainer/CacheLocationCheckBox
	var location := "global" if checkbox.button_pressed else "local"
	AppConfig.set_cache_location(location)

func save_theme_settings() -> void:
	var index: int = $ScrollContainer/MarginContainer/VBoxContainer/ThemeOptionButton.selected
	var theme_mode: ThemeManager.ThemeMode = ThemeManager.ThemeMode.LIGHT
	match index:
		0: theme_mode = ThemeManager.ThemeMode.LIGHT
		1: theme_mode = ThemeManager.ThemeMode.DARK
		2: theme_mode = ThemeManager.ThemeMode.AUTO
	ThemeManager.set_mode(theme_mode)

func save_editor_settings() -> void:
	AppConfig.set_editor_line_length(int($ScrollContainer/MarginContainer/VBoxContainer/LineLengthSpinBox.value))
	EventBus.editor_resized.emit()

func _on_theme_selected() -> void:
	save_theme_settings()

func _on_close_pressed() -> void:
	save_llm_settings()
	save_theme_settings()
	save_cache_settings()
	save_editor_settings()
	EventBus.settings_closed.emit()
	queue_free()


func _on_close_requested() -> void:
	save_llm_settings()
	save_theme_settings()
	save_cache_settings()
	save_editor_settings()
	EventBus.settings_closed.emit()
	queue_free()
