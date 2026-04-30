extends Node
## Utility for calling the Ollama Generate API endpoint.
##
## Usage (must be called from a Node context with await):
##   var response = await OllamaClient.generate("llama3", "Why is the sky blue?")
##   var json_response = await OllamaClient.generate_json("llama3", "Tell me a joke")
##   var running = await OllamaClient.is_ollama_running()

## Default Ollama API endpoint
const DEFAULT_ENDPOINT: String = "http://localhost:11434/api/generate"
## Endpoint to check if Ollama is running
const CHECK_ENDPOINT: String = "http://localhost:11434/api/tags"

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
## @param model The model name (e.g., "llama3", "mistral")
## @param prompt The prompt to send to the model
## @param options Optional dictionary with additional parameters
## @return Dictionary with response data or error information
func generate(model: String, prompt: String, options: Dictionary = {}) -> Dictionary:
	var request_body: Dictionary = _build_request_body(model, prompt, options)
	return await _make_api_request(DEFAULT_ENDPOINT, request_body, "generate")

## Generate JSON response from a model
## Sets format to "json" in the request options
## @param model The model name
## @param prompt The prompt to send to the model
## @param options Optional dictionary with additional parameters
## @return Dictionary with parsed JSON response or error information
func generate_json(model: String, prompt: String, options: Dictionary = {}) -> Dictionary:
	options["format"] = "json"
	var response: Dictionary = await generate(model, prompt, options)
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
	# Wait for the signal
	var response: Dictionary = await generate_complete
	print("[OllamaClient] Received response: %s" % JSON.stringify(response))
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
	print("[OllamaClient] Response body: %s" % response_body_str)

	if result == OK and response_code == 200:
		var json = JSON.new()
		var parse_err: int = json.parse(response_body_str)
		if parse_err == OK:
			var json_data: Dictionary = json.get_data()
			print("[OllamaClient] Parsed JSON: %s" % JSON.stringify(json_data))
			
			# Parse actual JSON response
			var data_string : String = json_data.get("response") if json_data.has("response") and json_data["response"] != "" else (json_data.get("thinking") if json_data.has("thinking") and json_data["thinking"] != "" else "")
			var json2 = JSON.new()
			var parse_err2: int = json2.parse(data_string)
			if parse_err == OK:
				generate_complete.emit({"response": json2.get_data(), "model": json_data.get("model", ""), "done": json_data.get("done", false)})
				return
			else:
				print("[OllamaClient] JSON parse error of response data: %d" % parse_err)
				generate_complete.emit({"error": "Failed to parse JSON response data", "raw_response": response_body_str, "parse_error": parse_err})
					
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

## Parse JSON from the response text
func _parse_json_response(response_text: String):
	var json = JSON.new()
	var err: int = json.parse(response_text)
	if err == OK:
		return json.get_data()
	return null

## Check if Ollama is running and accessible
func is_ollama_running() -> bool:
	print("[OllamaClient] Checking if Ollama is running...")
	current_request_type = "check"
	var headers: PackedStringArray = []

	var request_err: int = http_request.request(CHECK_ENDPOINT, headers, HTTPClient.METHOD_GET, "")

	if request_err != OK:
		print("[OllamaClient] ERROR: Failed to send check request, error code: %d" % request_err)
		current_request_type = ""
		return false

	print("[OllamaClient] Check request sent to %s, waiting for response..." % CHECK_ENDPOINT)
	# Wait for the signal
	var running: bool = await check_complete
	print("[OllamaClient] Ollama running: %s" % running)
	current_request_type = ""
	return running
