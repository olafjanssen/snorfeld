extends GenericCacheService
## GrammarService - Handles caching and analysis of paragraph grammar corrections

# Override: Get service name for signals
func _get_service_name() -> String:
	return "grammar"

# Override: Get cache subdirectory name
func _get_cache_subdir() -> String:
	return "paragraph"

# Override: Get JSONL filename
func _get_cache_filename() -> String:
	return "grammar.jsonl"

func _ready() -> void:
	CommandBus.priority_analysis.connect(_on_priority_analysis_requested)
	EventBus.folder_opened.connect(_on_folder_opened)
	CommandBus.start_analysis.connect(_on_start_analysis)
	EventBus.file_selected.connect(_on_file_selected)
	if BookService != null:
		BookService.project_loaded.connect(_on_project_loaded)
		BookService.project_unloaded.connect(_on_project_unloaded)


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
			print("[GrammarService] WARNING: Grammar LLM returned non-Dictionary JSON: %s" % parsed)
	else:
		print("[GrammarService] WARNING: Grammar LLM response error or not JSON")
		if llm_response.has("error"):
			print("[GrammarService] Grammar LLM Error: %s" % llm_response["error"])

	return {
		"corrected": corrected_text,
		"explanation": explanation,
		"model": model
	}


# Override: Analyze a paragraph and return grammar cache data
func _analyze(payload: Dictionary) -> Dictionary:
	var paragraph_hash: String = payload.get("hash", "")
	var paragraph: String = payload.get("paragraph", "")
	var file_content: String = payload.get("file_content", "")

	# Extract context from file_content
	var context_before := ""
	var context_after := ""
	if file_content.length() > 0 and paragraph.length() > 0:
		var paragraph_index := file_content.find(paragraph)
		if paragraph_index != -1:
			var before_start = max(0, paragraph_index - 1000)
			context_before = file_content.substr(before_start, paragraph_index - before_start)
			var after_start := paragraph_index + paragraph.length()
			var after_end = min(file_content.length(), after_start + 1000)
			context_after = file_content.substr(after_start, after_end - after_start)

	# Call LLM to analyze grammar
	var result = await analyze_grammar(paragraph, context_before, context_after)

	# Build cache data
	return {
		"paragraph_hash": paragraph_hash,
		"original_text": paragraph,
		"corrected": result.get("corrected", paragraph),
		"explanation": result.get("explanation", ""),
		"llm_model": result.get("model", "unknown"),
		"cached_at": Time.get_unix_time_from_system()
	}

# Override: Get cache key from data (uses paragraph_hash)
func _get_cache_key_from_data(data: Dictionary) -> String:
	if data.has("paragraph_hash"):
		return data["paragraph_hash"]
	return ""

## ============================================================================
## Queue Management
## ============================================================================

# Queue a paragraph for grammar analysis
func queue_paragraph(paragraph_hash: String, paragraph: String, file_content: String, file_path: String = "", priority: bool = false) -> void:
	var payload := {
		"hash": paragraph_hash,
		"paragraph": paragraph,
		"file_content": file_content,
		"file_path": file_path
	}
	queue_task(payload, priority)

# Queue all paragraphs from all files for grammar analysis
func queue_all_paragraphs() -> void:
	var all_files := BookService.get_all_files()
	for file_path in all_files:
		queue_file_paragraphs(file_path)

# Queue all paragraphs from a specific file
func queue_file_paragraphs(file_path: String) -> void:
	var file_data := BookService.get_file(file_path)
	if file_data.is_empty():
		return
	var content = file_data.get("content", "")
	if content == "":
		return

	var para_ids := BookService.get_paragraphs_for_file(file_path)
	for para_id in para_ids:
		var para_data = BookService.get_paragraph(para_id)
		var para_hash = para_data.get("hash", "")
		var para_text = para_data.get("text", "")

		if not is_cached(para_hash) and not is_queued(para_hash):
			queue_paragraph(para_hash, para_text, content, file_path)

## ============================================================================
## Getters
## ============================================================================

# Get cached grammar analysis for a paragraph by its hash
func get_grammar_cache(paragraph_hash: String) -> Dictionary:
	return get_cached(paragraph_hash)

## ============================================================================
## Signal Handlers
## ============================================================================

func _on_priority_analysis_requested(service_type: String, file_path: String, payload: Dictionary) -> void:
	if service_type != _get_service_name():
		return
	# Handle priority grammar analysis request
	var paragraph_hash: String = payload.get("hash", "")
	var paragraph: String = payload.get("paragraph", "")
	var line_number: int = payload.get("line_number", 0)

	if paragraph_hash == "" and line_number != 0:
		# Get paragraph from BookService
		var para_data: Dictionary = BookService.get_paragraph_at_line(file_path, line_number)
		if para_data.is_empty():
			return
		paragraph_hash = para_data.get("hash", "")
		paragraph = para_data.get("text", "")

	if paragraph_hash == "":
		return

	# Check if already cached
	if is_cached(paragraph_hash):
		return

	# Get file content
	var file_data := BookService.get_file(file_path)
	var file_content := ""
	if not file_data.is_empty():
		file_content = file_data.get("content", "")

	queue_paragraph(paragraph_hash, paragraph, file_content, file_path, true)

func _on_folder_opened(path: String) -> void:
	var cache_dir := path.path_join(".snorfeld").path_join(_get_cache_subdir())
	if FileUtils.dir_exists(cache_dir):
		# Ensure cache is loaded before cleanup
		_ensure_cache_loaded(cache_dir)
		EventBus.unified_cache_cleanup_started.emit(_get_service_name())
		var removed_count := _cleanup_unused_cache_files(cache_dir, path)
		EventBus.unified_cache_cleanup_completed.emit(_get_service_name(), removed_count)

func _on_project_loaded(path: String) -> void:
	# Load cache for this project
	var cache_dir := path.path_join(".snorfeld").path_join(_get_cache_subdir())
	_ensure_cache_loaded(cache_dir)

func _on_project_unloaded() -> void:
	clear_all_caches()

func _on_start_analysis(service_type: String, scope: String) -> void:
	if service_type != "GRAMMAR":
		return
	if scope == "project":
		queue_all_paragraphs()
	elif scope == "chapter":
		if current_file_path != "":
			queue_file_paragraphs(current_file_path)

func _on_file_selected(path: String) -> void:
	current_file_path = path
	current_file_content = FileUtils.read_file(path)

## ========================================================================================================================================================
## Cleanup
## ============================================================================

# Clean up cache entries that don't exist in the project anymore
func _cleanup_unused_cache_files(cache_path: String, _project_path: String) -> int:
	var removed_count := 0

	# Get valid hashes from BookService
	var valid_paragraph_hashes := BookService.get_all_paragraph_hashes()
	var valid_hash_set := {}
	for content_hash in valid_paragraph_hashes:
		valid_hash_set[content_hash] = true

	# Remove cache entries that don't have corresponding source
	var keys_to_remove := []
	for key in memory_cache:
		if not valid_hash_set.has(key):
			keys_to_remove.append(key)
			removed_count += 1

	# Remove from memory cache
	for key in keys_to_remove:
		memory_cache.erase(key)
		queued_keys.erase(key)

	# Rewrite the JSONL file
	_rewrite_jsonl_file(cache_path)

	return removed_count
