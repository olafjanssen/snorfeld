extends Node
# SettingsManager - Manages application configuration

const CONFIG_FILE := "user://settings.cfg"

# Default settings
const DEFAULT_LLM_ENDPOINT := "http://localhost:11434/api/generate"
const DEFAULT_LLM_CHECK_ENDPOINT := "http://localhost:11434/api/tags"
const DEFAULT_LLM_MODEL := "qwen3.5:9b"
const DEFAULT_LLM_TEMPERATURE := 0.3
const DEFAULT_LLM_MAX_TOKENS := 512

# Cached values
var _llm_endpoint: String
var _llm_check_endpoint: String
var _llm_model: String
var _llm_temperature: float
var _llm_max_tokens: int

func _ready() -> void:
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
		print("[SettingsManager] Loaded settings from config")
	else:
		# Use defaults
		_llm_endpoint = DEFAULT_LLM_ENDPOINT
		_llm_check_endpoint = DEFAULT_LLM_CHECK_ENDPOINT
		_llm_model = DEFAULT_LLM_MODEL
		_llm_temperature = DEFAULT_LLM_TEMPERATURE
		_llm_max_tokens = DEFAULT_LLM_MAX_TOKENS
		print("[SettingsManager] Config file not found, using defaults")


# Save all settings to config file
func save_settings() -> void:
	var config := ConfigFile.new()

	config.set_value("llm", "endpoint", _llm_endpoint)
	config.set_value("llm", "check_endpoint", _llm_check_endpoint)
	config.set_value("llm", "model", _llm_model)
	config.set_value("llm", "temperature", _llm_temperature)
	config.set_value("llm", "max_tokens", _llm_max_tokens)

	var err := config.save(CONFIG_FILE)
	if err == OK:
		print("[SettingsManager] Settings saved successfully")
	else:
		push_error("[SettingsManager] Failed to save settings")


# LLM-specific helpers
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
