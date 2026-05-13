extends Node
## AppConfig - Application configuration management
## Merges AppConfig (config storage) + SettingsHandler (UI management)

# gdlint:ignore-file:todo-comment

const CONFIG_FILE := "user://settings.cfg"
const SettingsPanelScene = preload("res://scenes/settings/settings_panel.tscn")

# Default settings
const DEFAULT_LLM_ENDPOINT := "http://localhost:11434/api/generate"
const DEFAULT_LLM_CHECK_ENDPOINT := "http://localhost:11434/api/tags"
const DEFAULT_LLM_MODEL := "qwen3.5:9b"
const DEFAULT_LLM_TEMPERATURE := 0.3  # Default sampling temperature for LLM
const DEFAULT_LLM_MAX_TOKENS := 512

# Embedding model defaults
const DEFAULT_EMBEDDING_ENDPOINT := "http://localhost:11434/api/embeddings"
const DEFAULT_EMBEDDING_MODEL := "qwen3-embedding:0.6b"

# Cache location: "local" for project folder, "global" for user data folder
const DEFAULT_CACHE_LOCATION := "global"

# Cached values
var _llm_endpoint: String
var _llm_check_endpoint: String
var _llm_model: String
var _llm_temperature: float
var _llm_max_tokens: int

# Embedding configuration cached values
var _embedding_endpoint: String
var _embedding_model: String

# Cache location setting
var _cache_location: String = DEFAULT_CACHE_LOCATION

# UI state
var settings_panel: Window

func _ready() -> void:
	# Connect to EventBus signals for UI
	CommandBus.open_settings.connect(_on_open_settings)
	EventBus.settings_closed.connect(_on_settings_closed)

	# Load settings
	load_settings()

# Load settings from config file
func load_settings() -> void:
	var config := ConfigFile.new()
	var err := config.load(CONFIG_FILE)

	if err == OK:
		_llm_endpoint = config.get_value("llm", "endpoint", DEFAULT_LLM_ENDPOINT)
		_llm_check_endpoint = config.get_value("llm", "check_endpoint", DEFAULT_LLM_CHECK_ENDPOINT)
		_llm_model = config.get_value("llm", "model", DEFAULT_LLM_MODEL)
		_llm_temperature = config.get_value("llm", "temperature", DEFAULT_LLM_TEMPERATURE)
		_llm_max_tokens = config.get_value("llm", "max_tokens", DEFAULT_LLM_MAX_TOKENS)
		_embedding_endpoint = config.get_value("embedding", "endpoint", DEFAULT_EMBEDDING_ENDPOINT)
		_embedding_model = config.get_value("embedding", "model", DEFAULT_EMBEDDING_MODEL)
		_cache_location = config.get_value("cache", "location", DEFAULT_CACHE_LOCATION)
	else:
		# Use defaults
		_llm_endpoint = DEFAULT_LLM_ENDPOINT
		_llm_check_endpoint = DEFAULT_LLM_CHECK_ENDPOINT
		_llm_model = DEFAULT_LLM_MODEL
		_llm_temperature = DEFAULT_LLM_TEMPERATURE
		_llm_max_tokens = DEFAULT_LLM_MAX_TOKENS
		_embedding_endpoint = DEFAULT_EMBEDDING_ENDPOINT
		_embedding_model = DEFAULT_EMBEDDING_MODEL
		_cache_location = DEFAULT_CACHE_LOCATION

# Save all settings to config file
func save_settings() -> void:
	var config := ConfigFile.new()

	config.set_value("llm", "endpoint", _llm_endpoint)
	config.set_value("llm", "check_endpoint", _llm_check_endpoint)
	config.set_value("llm", "model", _llm_model)
	config.set_value("llm", "temperature", _llm_temperature)
	config.set_value("llm", "max_tokens", _llm_max_tokens)
	config.set_value("embedding", "endpoint", _embedding_endpoint)
	config.set_value("embedding", "model", _embedding_model)
	config.set_value("cache", "location", _cache_location)

	var err := config.save(CONFIG_FILE)
	if err != OK:
		push_error("Failed to save settings")

# LLM configuration getters
func get_llm_endpoint() -> String:
	return _llm_endpoint

func get_llm_check_endpoint() -> String:
	return _llm_check_endpoint

func get_llm_model() -> String:
	return _llm_model

func get_llm_temperature() -> float:
	return _llm_temperature

func get_llm_max_tokens() -> int:
	return _llm_max_tokens

# LLM configuration setters
func set_llm_endpoint(endpoint: String) -> void:
	_llm_endpoint = endpoint
	save_settings()

func set_llm_check_endpoint(endpoint: String) -> void:
	_llm_check_endpoint = endpoint
	save_settings()

func set_llm_model(model: String) -> void:
	_llm_model = model
	save_settings()

func set_llm_temperature(temperature: float) -> void:
	_llm_temperature = temperature
	save_settings()

func set_llm_max_tokens(max_tokens: int) -> void:
	_llm_max_tokens = max_tokens
	save_settings()

# Embedding configuration getters
func get_embedding_endpoint() -> String:
	return _embedding_endpoint

func get_embedding_model() -> String:
	return _embedding_model

# Cache location getter
func get_cache_location() -> String:
	return _cache_location

# Embedding configuration setters
func set_embedding_endpoint(endpoint: String) -> void:
	_embedding_endpoint = endpoint
	save_settings()

func set_embedding_model(model: String) -> void:
	_embedding_model = model
	save_settings()

# Cache location setter
func set_cache_location(location: String) -> void:
	_cache_location = location
	save_settings()

# Settings panel management
func _on_open_settings() -> void:
	if settings_panel:
		settings_panel.queue_free()
	settings_panel = SettingsPanelScene.instantiate()
	get_tree().root.add_child(settings_panel)
	settings_panel.popup_centered(Vector2i(900, 1300))

func _on_settings_closed() -> void:
	if settings_panel:
		settings_panel.queue_free()
		settings_panel = null
