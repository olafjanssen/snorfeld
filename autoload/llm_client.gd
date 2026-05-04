extends Node
## Utility for calling LLM APIs (Ollama, Local, etc.)
##
## Usage (must be called from a Node context with await):
##   var response = await LLMClient.generate("llama3", "Why is the sky blue?")
##   var json_response = await LLMClient.generate_json("llama3", "Tell me a joke")
##   var running = await LLMClient.is_llm_running()

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
		model = AppConfig.get_llm_model()

	# Merge options with defaults from settings
	if not options.has("temperature"):
		options["temperature"] = AppConfig.get_llm_temperature()
	if not options.has("max_tokens"):
		options["max_tokens"] = AppConfig.get_llm_max_tokens()

	var request_body: Dictionary = _build_request_body(model, prompt, options)
	return await _make_api_request(AppConfig.get_llm_endpoint(), request_body, "generate")

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

## Build the request body dictionary for the LLM API
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

## Make the HTTP request to the LLM API
func _make_api_request(endpoint: String, request_body: Dictionary, request_type: String) -> Dictionary:
	print("[LLMClient] Making request to: %s" % endpoint)
	print("[LLMClient] Request body: %s" % JSON.stringify(request_body))
	current_request_type = request_type
	var headers: PackedStringArray = ["Content-Type: application/json"]
	var body_string: String = JSON.stringify(request_body)

	var request_err: int = http_request.request(endpoint, headers, HTTPClient.METHOD_POST, body_string)

	if request_err != OK:
		print("[LLMClient] ERROR: Failed to send request, error code: %d" % request_err)
		return {"error": "Failed to send request", "error_code": request_err}

	print("[LLMClient] Request sent, waiting for response...")
	var response: Dictionary = await generate_complete
	print("[LLMClient] Received response")
	return response

## Generic HTTP request completion callback
func _on_http_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	print("[LLMClient] HTTP callback: result=%d, response_code=%d" % [result, response_code])
	if current_request_type == "check":
		print("[LLMClient] Check request completed with code: %d" % response_code)
		check_complete.emit(response_code == 200)
		return

	# Otherwise it's a generate request
	var response_body_str: String = body.get_string_from_utf8()
	print("[LLMClient] Response body received")

	if result == OK and response_code == 200:
		var json = JSON.new()
		var parse_err: int = json.parse(response_body_str)
		if parse_err == OK:
			var json_data: Dictionary = json.get_data()
			generate_complete.emit({"json_data": json_data, "raw_response": response_body_str})
			return
		else:
			print("[LLMClient] JSON parse error: %d" % parse_err)
			generate_complete.emit({"error": "Failed to parse JSON response", "raw_response": response_body_str, "parse_error": parse_err})
			return
	elif response_code == 0:
		print("[LLMClient] Connection failed")
		generate_complete.emit({"error": "Connection failed - is LLM server running?", "error_code": response_code})
	else:
		print("[LLMClient] API request failed with code: %d" % response_code)
		generate_complete.emit({"error": "API request failed", "error_code": response_code, "response": response_body_str})

## Check if LLM server is running and accessible
func is_llm_running() -> bool:
	print("[LLMClient] Checking if LLM server is running...")
	current_request_type = "check"
	var headers: PackedStringArray = []

	var request_err: int = http_request.request(AppConfig.get_llm_check_endpoint(), headers, HTTPClient.METHOD_GET, "")

	if request_err != OK:
		print("[LLMClient] ERROR: Failed to send check request, error code: %d" % request_err)
		current_request_type = ""
		return false

	print("[LLMClient] Check request sent to %s, waiting for response..." % AppConfig.get_llm_check_endpoint())
	var running: bool = await check_complete
	print("[LLMClient] LLM server running: %s" % running)
	current_request_type = ""
	return running
