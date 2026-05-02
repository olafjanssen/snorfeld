extends Node
# Text analyzer for generating corrections and explanations using LLM

# Analyzes text for grammar/spelling corrections
func analyze_grammar(paragraph: String, context_before: String = "", context_after: String = "") -> Dictionary:
	print("[TextAnalyzer] Generating grammar LLM response for paragraph...")
	# Build context from surrounding text (trim to reasonable size)
	var context := ""
	if context_before.length() > 0 or context_after.length() > 0:
		# Take up to 100 words before and after
		var before_words := _get_words(context_before, 100)
		var after_words := _get_words(context_after, 100)
		context = "Context (text before and after):\n%s... %s...\n\n" % [before_words, after_words]

	# Call Ollama to get spelling/grammar corrections with explanations
	var prompt := """
You are a helpful writing assistant. Analyze the following text and provide:
1. A corrected version with improved spelling and grammar (keep the original meaning), be aware the text may contain dialogue between \"...\" and MarkDown markup.
2. A brief explanation of the changes made

Context:
%s

Paragraph to analyze:
%s

Respond with a JSON object containing 'corrected' and 'explanation' fields:
{
  "corrected": "[corrected text]",
  "explanation": "[brief explanation of changes]"
}
""" % [context, paragraph]

	var options := {"temperature": SettingsManager.get_llm_temperature(), "max_tokens": SettingsManager.get_llm_max_tokens()}
	var llm_response = await OllamaClient.generate_json(SettingsManager.get_llm_model(), prompt, options)

	var corrected_text: String = paragraph
	var explanation: String = ""
	var model: String = SettingsManager.get_llm_model()

	if llm_response.get("parsed_json", null) != null:
		# The OllamaClient.generate_json already parsed the JSON for us
		var parsed = llm_response["parsed_json"]
		if parsed is Dictionary:
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
func analyze_style(paragraph: String, context_before: String = "", context_after: String = "") -> Dictionary:
	# Build context from surrounding text (trim to reasonable size)
	var context := ""
	if context_before.length() > 0 or context_after.length() > 0:
		# Take up to 100 words before and after
		var before_words := _get_words(context_before, 100)
		var after_words := _get_words(context_after, 100)
		context = "Context (text before and after):\n%s... %s...\n\n" % [before_words, after_words]

	# Call Ollama to get stylistic improvements with explanations
	var prompt := """
You are a helpful writing assistant. Analyze the following text and provide:
1. An enhanced version with improved style, flow, and readability (keep the original meaning)
2. A brief explanation of the stylistic improvements made

Context:
%s

Paragraph to analyze:
%s

Respond with a JSON object containing 'enhanced' and 'explanation' fields:
{
  "enhanced": "[enhanced text]",
  "explanation": "[brief explanation of stylistic changes]"
}
""" % [context, paragraph]

	var options := {"temperature": SettingsManager.get_llm_temperature(), "max_tokens": SettingsManager.get_llm_max_tokens()}
	var llm_response = await OllamaClient.generate_json(SettingsManager.get_llm_model(), prompt, options)

	var enhanced_text: String = paragraph
	var explanation: String = ""
	var model: String = SettingsManager.get_llm_model()

	if llm_response.get("parsed_json", null) != null:
		# The OllamaClient.generate_json already parsed the JSON for us
		var parsed = llm_response["parsed_json"]
		if parsed is Dictionary:
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


# Helper function to get first N words from text
func _get_words(text: String, max_words: int) -> String:
	var words := text.split(" ", false)
	if words.size() <= max_words:
		return text
	var result_words := []
	for i in range(min(words.size(), max_words)):
		result_words.append(words[i])
	return " ".join(result_words)


# Analyzes text for structural/plot/pacing enhancements
func analyze_structure(paragraph: String, context_before: String = "", context_after: String = "", full_chapter: String = "") -> Dictionary:
	# Build context - use full chapter if available, otherwise use before/after
	var context := ""
	if full_chapter.length() > 0:
		# Use full chapter as context, trimmed to reasonable size
		context = "Full chapter context:\n%s...\n\n" % _get_words(full_chapter, 500)
	elif context_before.length() > 0 or context_after.length() > 0:
		# Fall back to before/after context
		var before_words := _get_words(context_before, 200)
		var after_words := _get_words(context_after, 200)
		context = "Surrounding text context:\n%s... %s...\n\n" % [before_words, after_words]

	# Call Ollama to get structural suggestions
	var prompt := """
You are a helpful writing assistant specializing in story structure. Analyze the following text and provide:
1. A rewrite for this paragraph to improve plot, pacing, or structural flow
2. A brief explanation of how this suggestion enhances the narrative

Context:
%s

Paragraph to analyze:
%s

Respond with a JSON object containing 'suggestion' and 'explanation' fields:
{
  "suggestion": "[structural suggestion]",
  "explanation": "[brief explanation of the structural improvement]"
}
""" % [context, paragraph]

	var options := {"temperature": SettingsManager.get_llm_temperature(), "max_tokens": SettingsManager.get_llm_max_tokens()}
	var llm_response = await OllamaClient.generate_json(SettingsManager.get_llm_model(), prompt, options)

	var suggestion: String = ""
	var explanation: String = ""
	var model: String = SettingsManager.get_llm_model()

	if llm_response.get("parsed_json", null) != null:
		var parsed = llm_response["parsed_json"]
		if parsed is Dictionary:
			if parsed.has("suggestion") and parsed["suggestion"] is String:
				suggestion = parsed["suggestion"]
			if parsed.has("explanation") and parsed["explanation"] is String:
				explanation = parsed["explanation"]
		else:
			print("[TextAnalyzer] WARNING: Structure LLM returned non-Dictionary JSON: %s" % parsed)
	else:
		print("[TextAnalyzer] WARNING: Structure LLM response error or not JSON")
		if llm_response.has("error"):
			print("[TextAnalyzer] Structure LLM Error: %s" % llm_response["error"])

	return {
		"suggestion": suggestion,
		"explanation": explanation,
		"model": model
	}


# Backward compatible wrapper - analyzes text for grammar corrections
func analyze_text(paragraph: String) -> Dictionary:
	return await analyze_grammar(paragraph)
