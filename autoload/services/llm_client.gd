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

## Request queue to ensure sequential processing
## Each request gets a completion object that will be set when the HTTP response arrives
var request_queue := []
var processing_request := false
var queue_mutex := Mutex.new()

## Current completion object for the request being processed (for callback to access)
var current_completion: Dictionary

## Signal for async completion (backward compatibility)
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
			var parsed_data := JsonUtils.parse_json(response_text)
			if not parsed_data.is_empty():
				response["parsed_json"] = parsed_data
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

## Make an HTTP request, queuing if another is in progress
func _make_api_request(endpoint: String, request_body: Dictionary, request_type: String) -> Dictionary:
	# Create completion object for this request
	var completion = {"response": null, "completed": false}

	queue_mutex.lock()
	request_queue.append({
		"endpoint": endpoint,
		"request_body": request_body,
		"request_type": request_type,
		"completion": completion
	})
	queue_mutex.unlock()

	# Start processing if not already
	if not processing_request:
		_process_next_queued_request()

	# Wait for completion
	while not completion["completed"]:
		await get_tree().process_frame

	return completion["response"]

## Process the next queued request
func _process_next_queued_request() -> void:
	if processing_request:
		return

	queue_mutex.lock()
	if request_queue.is_empty():
		queue_mutex.unlock()
		processing_request = false
		return

	var request = request_queue.pop_front()
	queue_mutex.unlock()

	processing_request = true
	current_request_type = request["request_type"]
	current_completion = request["completion"]

	print("[LLMClient] Making request to: %s" % request["endpoint"])
	print("[LLMClient] Request body: %s" % JsonUtils.stringify_json(request["request_body"]))

	var headers: PackedStringArray = ["Content-Type: application/json"]
	var body_string: String = JsonUtils.stringify_json(request["request_body"])
	var request_err: int

	# For GET requests (check endpoint), use GET method
	if request["request_type"] == "check":
		request_err = http_request.request(request["endpoint"], headers, HTTPClient.METHOD_GET, "")
	else:
		request_err = http_request.request(request["endpoint"], headers, HTTPClient.METHOD_POST, body_string)

	if request_err != OK:
		print("[LLMClient] ERROR: Failed to send request, error code: %d" % request_err)
		current_completion["response"] = {"error": "Failed to send request", "error_code": request_err}
		current_completion["completed"] = true
		current_completion = {}
		processing_request = false
		_process_next_queued_request()
		return

	print("[LLMClient] Request sent, waiting for response...")
	# Wait for the HTTP callback to set the response
	# The callback will check current_request_type and current_completion
	# and set the appropriate values
	while not current_completion["completed"]:
		await get_tree().process_frame

	print("[LLMClient] Request received response")
	current_completion = {}
	processing_request = false
	_process_next_queued_request()


## HTTP request completion callback
## Sets the response on the current completion object and emits signals for backward compatibility
func _on_http_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	print("[LLMClient] HTTP callback: result=%d, response_code=%d" % [result, response_code])

	if current_completion == null or current_completion.is_empty():
		print("[LLMClient] WARNING: No current completion object for callback")
		return

	if current_request_type == "check":
		print("[LLMClient] Check request completed with code: %d" % response_code)
		var is_running = (response_code == 200)
		current_completion["response"] = is_running
		current_completion["completed"] = true
		# Emit for backward compatibility
		check_complete.emit(is_running)
		return

	# Otherwise it's a generate request
	var response_body_str: String = body.get_string_from_utf8()
	print("[LLMClient] Response body received")

	var response_dict: Dictionary
	if result == OK and response_code == 200:
		var json_data: Dictionary = JsonUtils.parse_json(response_body_str)
		if not json_data.is_empty():
			response_dict = {"json_data": json_data, "raw_response": response_body_str}
		else:
			print("[LLMClient] JSON parse error")
			response_dict = {"error": "Failed to parse JSON response", "raw_response": response_body_str}
	elif response_code == 0:
		print("[LLMClient] Connection failed")
		response_dict = {"error": "Connection failed - is LLM server running?", "error_code": response_code}
	else:
		print("[LLMClient] API request failed with code: %d" % response_code)
		response_dict = {"error": "API request failed", "error_code": response_code, "response": response_body_str}

	current_completion["response"] = response_dict
	current_completion["completed"] = true
	# Emit for backward compatibility
	generate_complete.emit(response_dict)

## Check if LLM server is running and accessible
func is_llm_running() -> bool:
	var request_body: Dictionary = {}
	var result = await _make_api_request(AppConfig.get_llm_check_endpoint(), request_body, "check")
	return result
