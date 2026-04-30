extends Node
# Text analyzer for generating corrections and explanations using LLM

# Analyzes text for grammar/spelling corrections
func analyze_grammar(paragraph: String) -> Dictionary:
	print("[TextAnalyzer] Generating grammar LLM response for paragraph...")
	# Call Ollama to get spelling/grammar corrections with explanations
	var prompt := """
You are a helpful writing assistant. Analyze the following text and provide:
1. A corrected version with improved spelling and grammar (keep the original meaning)
2. A brief explanation of the changes made

Text to analyze:
%s

Respond with a JSON object containing 'corrected' and 'explanation' fields:
{
  "corrected": "[corrected text]",
  "explanation": "[brief explanation of changes]"
}
""" % paragraph

	print("[TextAnalyzer] Sending grammar prompt to Ollama (length: %d chars)" % prompt.length())
	var options := {"temperature": SettingsManager.get_llm_temperature(), "max_tokens": SettingsManager.get_llm_max_tokens()}
	var llm_response = await OllamaClient.generate_json(SettingsManager.get_llm_model(), prompt, options)
	print("[TextAnalyzer] Received grammar Ollama response")

	var corrected_text: String = paragraph
	var explanation: String = ""
	var model: String = SettingsManager.get_llm_model()

	if llm_response.get("parsed_json", null) != null:
		# The OllamaClient.generate_json already parsed the JSON for us
		var parsed = llm_response["parsed_json"]
		print("[TextAnalyzer] Parsed grammar JSON type: %s" % typeof(parsed))
		if parsed is Dictionary:
			print("[TextAnalyzer] Parsed grammar JSON: corrected=%s, explanation=%s" % [parsed.get("corrected", ""), parsed.get("explanation", "")])
			if parsed.has("corrected") and parsed["corrected"] is String:
				corrected_text = parsed["corrected"]
			if parsed.has("explanation") and parsed["explanation"] is String:
				explanation = parsed["explanation"]
		else:
			print("[TextAnalyzer] WARNING: Grammar LLM returned non-Dictionary JSON: %s" % parsed)
	else:
		print("[TextAnalyzer] WARNING: Grammar LLM response error or not JSON")
		if llm_response.has("error"):
			print("[TextAnalyzer] Grammar LLM Error: %s" % llm_response["error"])

	return {
		"corrected": corrected_text,
		"explanation": explanation,
		"model": model
	}


# Analyzes text for stylistic improvements
func analyze_style(paragraph: String) -> Dictionary:
	print("[TextAnalyzer] Generating style LLM response for paragraph...")
	# Call Ollama to get stylistic improvements with explanations
	var prompt := """
You are a helpful writing assistant. Analyze the following text and provide:
1. An enhanced version with improved style, flow, and readability (keep the original meaning)
2. A brief explanation of the stylistic improvements made

Text to analyze:
%s

Respond with a JSON object containing 'enhanced' and 'explanation' fields:
{
  "enhanced": "[enhanced text]",
  "explanation": "[brief explanation of stylistic changes]"
}
""" % paragraph

	print("[TextAnalyzer] Sending style prompt to Ollama (length: %d chars)" % prompt.length())
	var options := {"temperature": SettingsManager.get_llm_temperature(), "max_tokens": SettingsManager.get_llm_max_tokens()}
	var llm_response = await OllamaClient.generate_json(SettingsManager.get_llm_model(), prompt, options)
	print("[TextAnalyzer] Received style Ollama response")

	var enhanced_text: String = paragraph
	var explanation: String = ""
	var model: String = SettingsManager.get_llm_model()

	if llm_response.get("parsed_json", null) != null:
		# The OllamaClient.generate_json already parsed the JSON for us
		var parsed = llm_response["parsed_json"]
		print("[TextAnalyzer] Parsed style JSON type: %s" % typeof(parsed))
		if parsed is Dictionary:
			print("[TextAnalyzer] Parsed style JSON: enhanced=%s, explanation=%s" % [parsed.get("enhanced", ""), parsed.get("explanation", "")])
			if parsed.has("enhanced") and parsed["enhanced"] is String:
				enhanced_text = parsed["enhanced"]
			if parsed.has("explanation") and parsed["explanation"] is String:
				explanation = parsed["explanation"]
		else:
			print("[TextAnalyzer] WARNING: Style LLM returned non-Dictionary JSON: %s" % parsed)
	else:
		print("[TextAnalyzer] WARNING: Style LLM response error or not JSON")
		if llm_response.has("error"):
			print("[TextAnalyzer] Style LLM Error: %s" % llm_response["error"])

	return {
		"enhanced": enhanced_text,
		"explanation": explanation,
		"model": model
	}


# Backward compatible wrapper - analyzes text for grammar corrections
func analyze_text(paragraph: String) -> Dictionary:
	return await analyze_grammar(paragraph)
