extends Node
## Utility for calling the Ollama Generate API endpoint.
##
## Usage (must be called from a Node context with await):
##   var response = await OllamaClient.generate("llama3", "Why is the sky blue?")
##   var json_response = await OllamaClient.generate_json("llama3", "Tell me a joke")
##   var running = await OllamaClient.is_ollama_running()



## HTTP request node
var http_request: HTTPRequest

## Current request type tracking
var current_request_type: String = ""

## Signal for async completion
signal generate_complete(response: Dictionary)
signal check_complete(running: bool)

func _ready() -> void:
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_http_request_completed)

## Generate text from a model with a given prompt
func generate(model: String, prompt: String, options: Dictionary = {}) -> Dictionary:
	# Use model from settings if not provided
	if model == "" or model == null:
		model = SettingsManager.get_llm_model()

	# Merge options with defaults from settings
	if not options.has("temperature"):
		options["temperature"] = SettingsManager.get_llm_temperature()
	if not options.has("max_tokens"):
		options["max_tokens"] = SettingsManager.get_llm_max_tokens()

	var request_body: Dictionary = _build_request_body(model, prompt, options)
	return await _make_api_request(SettingsManager.get_llm_endpoint(), request_body, "generate")

## Generate JSON response from a model
## Sets format to "json" in the request options
func generate_json(model: String, prompt: String, options: Dictionary = {}) -> Dictionary:
	options["format"] = "json"
	var response: Dictionary = await generate(model, prompt, options)

	# Extract and parse the actual response data
	if response.get("error", null) == null and response.has("json_data"):
		var json_data: Dictionary = response["json_data"]
		var response_text: String = ""

		# Try response field first, then thinking
		if json_data.has("response") and json_data["response"] != "":
			response_text = json_data["response"]
		elif json_data.has("thinking"):
			response_text = json_data["thinking"]

		if response_text != "":
			var json = JSON.new()
			var parse_err: int = json.parse(response_text)
			if parse_err == OK:
				response["parsed_json"] = json.get_data()
				response["is_json"] = true
			else:
				response["is_json"] = false
			response["raw_response"] = response_text

	return response

## Build the request body dictionary for the Ollama API
func _build_request_body(model: String, prompt: String, options: Dictionary) -> Dictionary:
	var body: Dictionary = {
		"model": model,
		"prompt": prompt,
		"stream": options.get("stream", false),
		"temperature": options.get("temperature", 0.8),
		"top_p": options.get("top_p", 0.9),
		"top_k": options.get("top_k", 40),
		"max_tokens": options.get("max_tokens", 128)
	}

	if options.has("stop"):
		body["stop"] = options["stop"]
	if options.has("format"):
		body["format"] = options["format"]
	if options.has("seed"):
		body["seed"] = options["seed"]

	return body

## Make the HTTP request to the Ollama API
func _make_api_request(endpoint: String, request_body: Dictionary, request_type: String) -> Dictionary:
	print("[OllamaClient] Making request to: %s" % endpoint)
	print("[OllamaClient] Request body: %s" % JSON.stringify(request_body))
	current_request_type = request_type
	var headers: PackedStringArray = ["Content-Type: application/json"]
	var body_string: String = JSON.stringify(request_body)

	var request_err: int = http_request.request(endpoint, headers, HTTPClient.METHOD_POST, body_string)

	if request_err != OK:
		print("[OllamaClient] ERROR: Failed to send request, error code: %d" % request_err)
		return {"error": "Failed to send request", "error_code": request_err}

	print("[OllamaClient] Request sent, waiting for response...")
	var response: Dictionary = await generate_complete
	print("[OllamaClient] Received response")
	return response

## Generic HTTP request completion callback
func _on_http_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	print("[OllamaClient] HTTP callback: result=%d, response_code=%d" % [result, response_code])
	if current_request_type == "check":
		print("[OllamaClient] Check request completed with code: %d" % response_code)
		check_complete.emit(response_code == 200)
		return

	# Otherwise it's a generate request
	var response_body_str: String = body.get_string_from_utf8()
	print("[OllamaClient] Response body received")

	if result == OK and response_code == 200:
		var json = JSON.new()
		var parse_err: int = json.parse(response_body_str)
		if parse_err == OK:
			var json_data: Dictionary = json.get_data()
			generate_complete.emit({"json_data": json_data, "raw_response": response_body_str})
			return
		else:
			print("[OllamaClient] JSON parse error: %d" % parse_err)
			generate_complete.emit({"error": "Failed to parse JSON response", "raw_response": response_body_str, "parse_error": parse_err})
			return
	elif response_code == 0:
		print("[OllamaClient] Connection failed")
		generate_complete.emit({"error": "Connection failed - is Ollama running?", "error_code": response_code})
	else:
		print("[OllamaClient] API request failed with code: %d" % response_code)
		generate_complete.emit({"error": "API request failed", "error_code": response_code, "response": response_body_str})

## Check if Ollama is running and accessible
func is_ollama_running() -> bool:
	print("[OllamaClient] Checking if Ollama is running...")
	current_request_type = "check"
	var headers: PackedStringArray = []

	var request_err: int = http_request.request(SettingsManager.get_llm_check_endpoint(), headers, HTTPClient.METHOD_GET, "")

	if request_err != OK:
		print("[OllamaClient] ERROR: Failed to send check request, error code: %d" % request_err)
		current_request_type = ""
		return false

	print("[OllamaClient] Check request sent to %s, waiting for response..." % SettingsManager.get_llm_check_endpoint())
	var running: bool = await check_complete
	print("[OllamaClient] Ollama running: %s" % running)
	current_request_type = ""
	return running
