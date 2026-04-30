extends Node
# Text analyzer for generating corrections and explanations using LLM

# Analyzes text and returns corrections with explanations
func analyze_text(paragraph: String) -> Dictionary:
	print("[TextAnalyzer] Generating LLM response for paragraph...")
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

	print("[TextAnalyzer] Sending prompt to Ollama (length: %d chars)" % prompt.length())
	var options := {"temperature": SettingsManager.get_llm_temperature(), "max_tokens": SettingsManager.get_llm_max_tokens()}
	var llm_response = await OllamaClient.generate_json(SettingsManager.get_llm_model(), prompt, options)
	print("[TextAnalyzer] Received Ollama response")

	var corrected_text := paragraph
	var explanation := ""
	var model := SettingsManager.get_llm_model()

	if llm_response.get("parsed_json", null) != null:
		# The OllamaClient.generate_json already parsed the JSON for us
		var parsed = llm_response["parsed_json"]
		print("[TextAnalyzer] Parsed JSON: corrected=%s, explanation=%s" % [parsed.get("corrected", ""), parsed.get("explanation", "")])
		if parsed is Dictionary:
			if parsed.has("corrected"):
				corrected_text = parsed["corrected"]
			if parsed.has("explanation"):
				explanation = parsed["explanation"]
	else:
		print("[TextAnalyzer] WARNING: LLM response error or not JSON")
		if llm_response.has("error"):
			print("[TextAnalyzer] LLM Error: %s" % llm_response["error"])

	return {
		"corrected_text": corrected_text,
		"explanation": explanation,
		"model": model
	}
