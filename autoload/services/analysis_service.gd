extends Node
# Analysis service for generating corrections and explanations using LLM

# Analyzes text for grammar/spelling corrections
func analyze_grammar(paragraph: String, context_before: String = "", context_after: String = "") -> Dictionary:
	# Build context from surrounding text (trim to reasonable size)
	var context := ""
	if context_before.length() > 0 or context_after.length() > 0:
		# Take up to 100 words before and after
		var before_words := PromptTemplates.get_words(context_before, 100)
		var after_words := PromptTemplates.get_words(context_after, 100)
		context = "Context (text before and after):\n%s... %s...\n\n" % [before_words, after_words]

	# Format prompt using template
	var prompt := PromptTemplates.format_prompt(PromptTemplates.GRAMMAR_PROMPT, {
		"context": context,
		"paragraph": paragraph
	})

	var options := {"temperature": AppConfig.get_llm_temperature(), "max_tokens": AppConfig.get_llm_max_tokens()}
	var llm_response = await LLMClient.generate_json(AppConfig.get_llm_model(), prompt, options)

	var corrected_text: String = paragraph
	var explanation: String = ""
	var model: String = AppConfig.get_llm_model()

	if llm_response.get("parsed_json", null) != null:
		# The LLMClient.generate_json already parsed the JSON for us
		var parsed = llm_response["parsed_json"]
		if parsed is Dictionary:
			if parsed.has("corrected") and parsed["corrected"] is String:
				corrected_text = parsed["corrected"]
			if parsed.has("explanation") and parsed["explanation"] is String:
				explanation = parsed["explanation"]
		else:
			print("[AnalysisService] WARNING: Grammar LLM returned non-Dictionary JSON: %s" % parsed)
	else:
		print("[AnalysisService] WARNING: Grammar LLM response error or not JSON")
		if llm_response.has("error"):
			print("[AnalysisService] Grammar LLM Error: %s" % llm_response["error"])

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
		var before_words := PromptTemplates.get_words(context_before, 100)
		var after_words := PromptTemplates.get_words(context_after, 100)
		context = "Context (text before and after):\n%s... %s...\n\n" % [before_words, after_words]

	# Format prompt using template
	var prompt := PromptTemplates.format_prompt(PromptTemplates.STYLE_PROMPT, {
		"context": context,
		"paragraph": paragraph
	})

	var options := {"temperature": AppConfig.get_llm_temperature(), "max_tokens": AppConfig.get_llm_max_tokens()}
	var llm_response = await LLMClient.generate_json(AppConfig.get_llm_model(), prompt, options)

	var enhanced_text: String = paragraph
	var explanation: String = ""
	var model: String = AppConfig.get_llm_model()

	if llm_response.get("parsed_json", null) != null:
		# The LLMClient.generate_json already parsed the JSON for us
		var parsed = llm_response["parsed_json"]
		if parsed is Dictionary:
			if parsed.has("enhanced") and parsed["enhanced"] is String:
				enhanced_text = parsed["enhanced"]
			if parsed.has("explanation") and parsed["explanation"] is String:
				explanation = parsed["explanation"]
		else:
			print("[AnalysisService] WARNING: Style LLM returned non-Dictionary JSON: %s" % parsed)
	else:
		print("[AnalysisService] WARNING: Style LLM response error or not JSON")
		if llm_response.has("error"):
			print("[AnalysisService] Style LLM Error: %s" % llm_response["error"])

	return {
		"enhanced": enhanced_text,
		"explanation": explanation,
		"model": model
	}


# Analyzes text for structural/plot/pacing enhancements
func analyze_structure(paragraph: String, context_before: String = "", context_after: String = "", full_chapter: String = "") -> Dictionary:
	# Build context - use full chapter if available, otherwise use before/after
	var context := ""
	if full_chapter.length() > 0:
		# Use full chapter as context, trimmed to reasonable size
		context = "Full chapter context:\n%s...\n\n" % PromptTemplates.get_words(full_chapter, 500)
	elif context_before.length() > 0 or context_after.length() > 0:
		# Fall back to before/after context
		var before_words := PromptTemplates.get_words(context_before, 200)
		var after_words := PromptTemplates.get_words(context_after, 200)
		context = "Surrounding text context:\n%s... %s...\n\n" % [before_words, after_words]

	# Format prompt using template
	var prompt := PromptTemplates.format_prompt(PromptTemplates.STRUCTURE_PROMPT, {
		"context": context,
		"paragraph": paragraph
	})

	var options := {"temperature": AppConfig.get_llm_temperature(), "max_tokens": AppConfig.get_llm_max_tokens()}
	var llm_response = await LLMClient.generate_json(AppConfig.get_llm_model(), prompt, options)

	var suggestion: String = ""
	var explanation: String = ""
	var model: String = AppConfig.get_llm_model()

	if llm_response.get("parsed_json", null) != null:
		var parsed = llm_response["parsed_json"]
		if parsed is Dictionary:
			if parsed.has("suggestion") and parsed["suggestion"] is String:
				suggestion = parsed["suggestion"]
			if parsed.has("explanation") and parsed["explanation"] is String:
				explanation = parsed["explanation"]
		else:
			print("[AnalysisService] WARNING: Structure LLM returned non-Dictionary JSON: %s" % parsed)
	else:
		print("[AnalysisService] WARNING: Structure LLM response error or not JSON")
		if llm_response.has("error"):
			print("[AnalysisService] Structure LLM Error: %s" % llm_response["error"])

	return {
		"suggestion": suggestion,
		"explanation": explanation,
		"model": model
	}


# Backward compatible wrapper - analyzes text for grammar corrections
func analyze_text(paragraph: String) -> Dictionary:
	return await analyze_grammar(paragraph)
