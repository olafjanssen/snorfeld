extends Node
## Utility for calling the Ollama Generate API endpoint.
##
## Usage (must be called from a Node context with await):
##   var response = await OllamaClient.generate("llama3", "Why is the sky blue?")
##   var json_response = await OllamaClient.generate_json("llama3", "Tell me a joke")
##   var running = await OllamaClient.is_ollama_running()

## Default Ollama API endpoint
const DEFAULT_ENDPOINT: String = "http://localhost:11434/api/generate"

## Generate text from a model with a given prompt
## @param model The model name (e.g., "llama3", "mistral")
## @param prompt The prompt to send to the model
## @param options Optional dictionary with additional parameters:
##   - temperature: Float (default: 0.8)
##   - top_p: Float (default: 0.9)
##   - top_k: Int (default: 40)
##   - max_tokens: Int (default: 128)
##   - stop: Array of strings to stop generation
##   - stream: Bool (default: false)
## @return Dictionary with response data or error information
func generate(model: String, prompt: String, options: Dictionary = {}) -> Dictionary:
	var request_body: Dictionary = _build_request_body(model, prompt, options)
	return await _make_api_request(DEFAULT_ENDPOINT, request_body)

## Generate JSON response from a model
## Sets format to "json" in the request options
## @param model The model name
## @param prompt The prompt to send to the model
## @param options Optional dictionary with additional parameters
## @return Dictionary with parsed JSON response or error information
func generate_json(model: String, prompt: String, options: Dictionary = {}) -> Dictionary:
	options["format"] = "json"
	var response: Dictionary = await generate(model, prompt, options)

	if response.get("error", null) == null and response.get("response", null) != null:
		var json_result = _parse_json_response(response["response"])
		if json_result != null:
			response["parsed_json"] = json_result
			response["is_json"] = true
		else:
			response["is_json"] = false

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
func _make_api_request(endpoint: String, request_body: Dictionary) -> Dictionary:
	var http = HTTPRequest.new()
	add_child(http)

	var headers: PackedStringArray = ["Content-Type: application/json"]
	var body_string: String = JSON.stringify(request_body)

	var request_err: int = http.request(endpoint, headers, HTTPClient.METHOD_POST, body_string)

	if request_err != OK:
		http.queue_free()
		return {"error": "Failed to send request", "error_code": request_err}

	# Wait for completion
	while http.get_http_client_status() == HTTPClient.STATUS_REQUESTING:
		await http.request_completed

	var response_code: int = http.get_response_code()
	var response_body: PackedByteArray = http.get_response_body()
	var response_body_str: String = response_body.get_string_from_utf8()

	# Clean up
	http.queue_free()

	if response_code == 200:
		var json = JSON.new()
		var parse_err: int = json.parse(response_body_str)
		if parse_err == OK:
			var result: Dictionary = json.get_data()
			if result.has("response"):
				return {"response": result["response"], "model": result.get("model", ""), "done": result.get("done", false)}
			else:
				return {"error": "Unexpected response format", "raw_response": response_body_str}
		else:
			return {"error": "Failed to parse JSON response", "raw_response": response_body_str, "parse_error": parse_err}
	elif response_code == 0:
		return {"error": "Connection failed - is Ollama running?", "error_code": response_code}
	else:
		return {"error": "API request failed", "error_code": response_code, "response": response_body_str}

## Parse JSON from the response text
func _parse_json_response(response_text: String):
	var json = JSON.new()
	var err: int = json.parse(response_text)
	if err == OK:
		return json.get_data()
	return null

## Check if Ollama is running and accessible
func is_ollama_running() -> bool:
	var http = HTTPRequest.new()
	add_child(http)

	var headers: PackedStringArray = []
	var request_err: int = http.request(DEFAULT_ENDPOINT, headers, HTTPClient.METHOD_GET, "")

	if request_err != OK:
		http.queue_free()
		return false

	while http.get_http_client_status() == HTTPClient.STATUS_REQUESTING:
		await http.request_completed

	var result = http.get_response_code() == 200
	http.queue_free()
	return result
