extends AnalysisService
## DictionaryService - Provides dictionary and thesaurus lookups using LLM
## Extends AnalysisService for built-in caching, queue management, and signals

# gdlint:ignore-file:long-function,long-line,missing-type-hint

# Signal for when word info is ready
signal word_info_ready(word: String, info: Dictionary)

func _ready() -> void:
	# Configure service properties
	service_name = "dictionary"
	cache_subdir = "dictionary"
	cache_filename = "dictionary.jsonl"
	# Don't merge - each word is unique
	should_merge_on_duplicate = false

	# Call parent ready to set up signals and state
	super()

	# Load dictionary cache from disk
	var cache_dir: String = _get_dictionary_cache_dir()
	_ensure_cache_loaded(cache_dir)

## Get dictionary and thesaurus info for a word (async version)
## word: The word to look up
## context: The sentence or paragraph for context (used in LLM prompt but NOT in cache key)
## Returns: Dictionary with 'definition' and 'synonyms' arrays
func get_word_info(word: String, context: String = "") -> Dictionary:
	# Ensure cache is loaded
	var cache_dir: String = _get_dictionary_cache_dir()
	_ensure_cache_loaded(cache_dir)

	var source_lang: String = AppConfig.get_source_language()
	var target_lang: String = AppConfig.get_target_language()

	# Create cache key (NO context to avoid mismatches between hover and async)
	var cache_key: String = _make_cache_key(word, source_lang, target_lang)

	# Check memory cache first
	if memory_cache.has(cache_key):
		return memory_cache[cache_key]

	# Check if already queued
	if queued_keys.has(cache_key):
		# Wait for it to complete
		while queued_keys.has(cache_key):
			await get_tree().process_frame
		return memory_cache.get(cache_key, {})

	# Create payload for analysis
	# Note: AnalysisService requires file_path, but DictionaryService is word-based
	# We use a placeholder since we don't need file-based caching
	var payload: Dictionary = {
		"hash": cache_key,
		"word": word,
		"context": context,
		"source_lang": source_lang,
		"target_lang": target_lang,
		"file_path": "dictionary.gd"
	}

	# Queue the task
	queue_task(payload, true)  # Priority = true for immediate processing

	# Wait for the result to be cached
	while not memory_cache.has(cache_key):
		await get_tree().process_frame

	return memory_cache[cache_key]

## Get word info synchronously from cache only (for tooltips)
## Returns empty dict if not cached
func get_cached_word_info(word: String, context: String = "") -> Dictionary:
	# Ensure cache is loaded
	var cache_dir: String = _get_dictionary_cache_dir()
	_ensure_cache_loaded(cache_dir)

	var source_lang: String = AppConfig.get_source_language()
	var target_lang: String = AppConfig.get_target_language()
	# Match the cache key format from get_word_info (no context)
	var cache_key: String = _make_cache_key(word, source_lang, target_lang)

	if memory_cache.has(cache_key):
		return memory_cache[cache_key]
	return {}

## Override _analyze to provide the actual dictionary lookup
func _analyze(payload: Dictionary) -> Dictionary:
	var word: String = payload.get("word", "")
	var context: String = payload.get("context", "")
	var source_lang: String = payload.get("source_lang", "en")
	var target_lang: String = payload.get("target_lang", "en")

	# Build prompt for LLM
	var prompt: String = _build_dictionary_prompt(word, context, source_lang, target_lang)

	# Generate response from LLM
	var response: Dictionary = await LLMClient.generate_json("", prompt, {"temperature": 0.3, "max_tokens": 512})

	var result: Dictionary
	if response.get("error", null) != null:
		# LLM returned an error
		result = {"error": response["error"], "word": word}
	elif response.get("parsed_json", null) != null:
		# Successfully parsed JSON
		result = response["parsed_json"]
	elif response.get("raw_response", "") != "":
		# Try to parse raw response
		result = _parse_dictionary_response(response["raw_response"])
		if result.has("error") and result["error"] == "Failed to parse LLM response":
			result["word"] = word
	else:
		# No response from LLM
		result = {"error": "No response from LLM", "word": word}

	# Add metadata for caching
	if not result.has("error"):
		result["hash"] = payload.get("hash", "")
		result["word"] = word
		result["source_lang"] = source_lang
		result["target_lang"] = target_lang
		result["context"] = context

	return result

## Build the LLM prompt for dictionary/thesaurus lookup
func _build_dictionary_prompt(word: String, context: String, source_lang: String, target_lang: String) -> String:
	var prompt: String = """
You are a helpful dictionary and thesaurus assistant.
Return a JSON object with the following structure for the word '{{WORD}}':
{
  "word": "the word itself",
  "definition": "clear, concise definition in {{SOURCE_LANG}} language",
  "synonyms": [
    {
      "word": "synonym1",
      "difference": "subtle difference from the original word and why it could work better in the context"
    },
    {
      "word": "synonym2",
      "difference": "subtle difference from the original word and why it could work better in the context"
    }
  ]
}

Guidelines:
- Provide 3-8 high-quality synonyms
- For each synonym, explain the subtle difference in meaning/connotation in one short phrase
- Definition should be accurate for the word in context
- Use {{SOURCE_LANG}} language for all responses
- Be concise but precise
""".replace("{{WORD}}", word).replace("{{SOURCE_LANG}}", source_lang)

	if context != "":
		prompt += "\n\nContext from text: " + context
		prompt += "\nConsider the meaning of the word in this specific context."

	prompt += "\n\nReturn ONLY the JSON object, no other text."

	return prompt

## Parse LLM response into structured dictionary
func _parse_dictionary_response(response: String) -> Dictionary:
	# Try to parse as JSON first
	var json_data: Dictionary = JsonUtils.parse_json(response)
	if not json_data.is_empty():
		return json_data

	# If there's extra text before/after the JSON, try to extract it
	# Look for the first { and last }
	var start_brace: int = response.find("{")
	var end_brace: int = response.rfind("}")
	if start_brace >= 0 and end_brace > start_brace:
		var json_substring: String = response.substr(start_brace, end_brace - start_brace + 1)
		json_data = JsonUtils.parse_json(json_substring)
		if not json_data.is_empty():
			return json_data

	# Return error
	return {"error": "Failed to parse LLM response", "raw_response": response}

## Make a cache key from word and languages (NO context to avoid mismatches)
func _make_cache_key(word: String, source_lang: String, target_lang: String, context_hash: String = "") -> String:
	return "%s|%s|%s" % [word.to_lower(), source_lang, target_lang]

## Override _get_cache_key to use our custom key
func _get_cache_key(payload: Dictionary) -> String:
	return payload.get("hash", "")

## Get the cache directory for dictionary
## Uses a global cache since dictionary is word-based, not file-based
func _get_dictionary_cache_dir() -> String:
	# Use global cache location
	var cache_location := AppConfig.get_cache_location()
	if cache_location == "global":
		# Use a dummy file path to get the global cache dir
		var cache_dir: String = _get_global_cache_dir_for_path("dummy.txt")
		return cache_dir.get_base_dir().path_join(cache_subdir)
	else:
		# For project cache, use project .snorfeld dir
		return "res://.snorfeld".path_join(cache_subdir)

## Override _process_task to use dictionary cache directory
## We still use file-based JSONL caching but with a global cache dir
func _process_task(task: Dictionary) -> void:
	# Store task info before processing for signal emission
	var task_word: String = task.get("word", "")
	var task_hash: String = _get_cache_key(task)

	# Call our analyze directly
	var result: Dictionary = await _analyze(task)

	if result == null or result.is_empty():
		# Clear queued flag on error
		if queued_keys.has(task_hash):
			queued_keys.erase(task_hash)
		return

	# Store in memory cache
	memory_cache[task_hash] = result

	# Save to disk
	var cache_dir: String = _get_dictionary_cache_dir()
	_save_to_jsonl(cache_dir, result)

	# Clear queued flag
	if queued_keys.has(task_hash):
		queued_keys.erase(task_hash)

	# Emit completion with task info for signal
	_emit_task_completed(task_queue.size(), task_word, result)

## Override _emit_task_completed to also emit word_info_ready signal
func _emit_task_completed(remaining: int, completed_word: String = "", completed_result: Dictionary = {}) -> void:
	super._emit_task_completed(remaining)
	# Emit the word_info_ready signal with the completed task info
	if completed_word != "" and not completed_result.is_empty():
		word_info_ready.emit(completed_word, completed_result)

## Get word info with context from a sentence
## Extracts the sentence containing the word from the paragraph
func get_word_info_with_sentence(word: String, paragraph: String) -> Dictionary:
	# Extract sentence containing the word
	var sentence: String = _extract_sentence_containing_word(paragraph, word)
	return await get_word_info(word, sentence)

## Extract sentence containing a specific word from paragraph
func _extract_sentence_containing_word(paragraph: String, word: String) -> String:
	var sentences: PackedStringArray = paragraph.split(". ")
	# Also try other sentence terminators
	if sentences.size() == 1:
		sentences = paragraph.split("! ")
		if sentences.size() == 1:
			sentences = paragraph.split("? ")
			if sentences.size() == 1:
				# Try splitting by newlines
				sentences = paragraph.split("\n")

	for sent in sentences:
		if sent.contains(word):
			# Add back the terminator if it was stripped
			var cleaned: String = sent.strip_edges()
			if paragraph.find(sent + ".") != -1:
				cleaned += "."
			elif paragraph.find(sent + "!") != -1:
				cleaned += "!"
			elif paragraph.find(sent + "?") != -1:
				cleaned += "?"
			return cleaned

	# Fallback: return the whole paragraph
	return paragraph
