extends ContentCache
# Paragraph service - handles caching and analysis of paragraph results
# Uses BookService for project content model, JSONL format with in-memory cache for efficiency
# Now supports separate caching for grammar, style, and structure analyses

const PARAGRAPH_DIR_NAME := "paragraph"
const GRAMMAR_JSONL_FILENAME := "grammar.jsonl"
const STYLE_JSONL_FILENAME := "style.jsonl"
const STRUCTURE_JSONL_FILENAME := "structure.jsonl"

# In-memory caches: key = paragraph_hash, value = cache data
var grammar_cache: Dictionary = {}
var style_cache: Dictionary = {}
var structure_cache: Dictionary = {}
# Track which cache directories have been loaded into memory
var loaded_cache_dirs: Dictionary = {}
# Track which paragraphs are currently queued per analysis type (to prevent duplicate queuing)
var queued_keys_grammar: Dictionary = {}
var queued_keys_style: Dictionary = {}
var queued_keys_structure: Dictionary = {}

func _ready() -> void:
	EventBus.request_priority_analysis.connect(_on_priority_analysis_requested)
	EventBus.folder_opened.connect(_on_folder_opened)
	EventBus.run_all_analyses.connect(_on_run_all_analyses)
	EventBus.run_chapter_analyses.connect(_on_run_chapter_analyses)
	EventBus.file_selected.connect(_on_file_selected)
	if BookService != null:
		BookService.project_loaded.connect(_on_project_loaded)
		BookService.project_unloaded.connect(_on_project_unloaded)


# Override: Get cache subdirectory name
func _get_cache_subdir() -> String:
	return PARAGRAPH_DIR_NAME


# Override: Process a single task
func _process_task(task: Dictionary):
	var paragraph_hash: String = task["hash"]
	var paragraph: String = task.get("paragraph", "")
	var file_content: String = task.get("file_content", "")
	var file_path: String = task.get("file_path", "")
	var analysis_type: int = task.get("analysis_type", 0)

	# Check if already cached for this analysis type
	if _is_cached(paragraph_hash, analysis_type):
		_remove_from_queued_keys(paragraph_hash, analysis_type)
		return

	await _create_and_store_cache(paragraph_hash, paragraph, file_content, file_path, analysis_type)
	_remove_from_queued_keys(paragraph_hash, analysis_type)


# Check if a paragraph hash is cached for a specific analysis type
func _is_cached(paragraph_hash: String, analysis_type: int) -> bool:
	match analysis_type:
		EventBus.AnalysisType.GRAMMAR:
			return grammar_cache.has(paragraph_hash)
		EventBus.AnalysisType.STYLE:
			return style_cache.has(paragraph_hash)
		EventBus.AnalysisType.STRUCTURE:
			return structure_cache.has(paragraph_hash)
	return false


# Remove from queued keys for a specific analysis type
func _remove_from_queued_keys(paragraph_hash: String, analysis_type: int) -> void:
	match analysis_type:
		EventBus.AnalysisType.GRAMMAR:
			queued_keys_grammar.erase(paragraph_hash)
		EventBus.AnalysisType.STYLE:
			queued_keys_style.erase(paragraph_hash)
		EventBus.AnalysisType.STRUCTURE:
			queued_keys_structure.erase(paragraph_hash)


# Override: Emit queue updated signal
func _emit_queue_updated() -> void:
	EventBus.cache_queue_updated.emit(task_queue.size(), processing)


# Override: Emit task started signal
func _emit_task_started(remaining: int) -> void:
	EventBus.cache_task_started.emit(remaining)


# Override: Emit task completed signal
func _emit_task_completed(remaining: int) -> void:
	EventBus.cache_task_completed.emit(remaining)


# Get cache directory for a file path
func _get_cache_dir_for_file(file_path: String) -> String:
	return file_path.get_base_dir().path_join(".snorfeld").path_join(PARAGRAPH_DIR_NAME)


# Ensure a cache directory's JSONL files are loaded into memory
func _ensure_cache_loaded(cache_dir: String) -> void:
	if loaded_cache_dirs.get(cache_dir, false):
		return
	if FileUtils.dir_exists(cache_dir):
		_load_grammar_jsonl_cache(cache_dir)
		_load_style_jsonl_cache(cache_dir)
		_load_structure_jsonl_cache(cache_dir)
	loaded_cache_dirs[cache_dir] = true


# Load grammar JSONL cache file into memory
func _load_grammar_jsonl_cache(cache_dir: String) -> void:
	var jsonl_path := cache_dir.path_join(GRAMMAR_JSONL_FILENAME)
	if not FileUtils.file_exists(jsonl_path):
		return
	var content := FileUtils.read_file(jsonl_path)
	var lines := content.split("\n")
	for line in lines:
		line = line.strip_edges()
		if line == "":
			continue
		var data := JsonUtils.parse_json(line)
		if data == null or data.is_empty():
			continue
		var paragraph_hash = data.get("paragraph_hash", "")
		if paragraph_hash != "":
			grammar_cache[paragraph_hash] = data


# Load style JSONL cache file into memory
func _load_style_jsonl_cache(cache_dir: String) -> void:
	var jsonl_path := cache_dir.path_join(STYLE_JSONL_FILENAME)
	if not FileUtils.file_exists(jsonl_path):
		return
	var content := FileUtils.read_file(jsonl_path)
	var lines := content.split("\n")
	for line in lines:
		line = line.strip_edges()
		if line == "":
			continue
		var data := JsonUtils.parse_json(line)
		if data == null or data.is_empty():
			continue
		var paragraph_hash = data.get("paragraph_hash", "")
		if paragraph_hash != "":
			style_cache[paragraph_hash] = data


# Load structure JSONL cache file into memory
func _load_structure_jsonl_cache(cache_dir: String) -> void:
	var jsonl_path := cache_dir.path_join(STRUCTURE_JSONL_FILENAME)
	if not FileUtils.file_exists(jsonl_path):
		return
	var content := FileUtils.read_file(jsonl_path)
	var lines := content.split("\n")
	for line in lines:
		line = line.strip_edges()
		if line == "":
			continue
		var data := JsonUtils.parse_json(line)
		if data == null or data.is_empty():
			continue
		var paragraph_hash = data.get("paragraph_hash", "")
		if paragraph_hash != "":
			structure_cache[paragraph_hash] = data


# Creates cache entry and stores in memory + appends to JSONL file
# analysis_type: 0=GRAMMAR, 1=STYLE, 2=STRUCTURE
func _create_and_store_cache(paragraph_hash: String, paragraph: String, file_content: String, file_path: String = "", analysis_type: int = 0) -> void:
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

	# Run only the requested analysis type
	var result: Dictionary = {}
	match analysis_type:
		EventBus.AnalysisType.GRAMMAR:
			result = await AnalysisService.analyze_grammar(paragraph, context_before, context_after)
		EventBus.AnalysisType.STYLE:
			result = await AnalysisService.analyze_style(paragraph, context_before, context_after)
		EventBus.AnalysisType.STRUCTURE:
			result = await AnalysisService.analyze_structure(paragraph, context_before, context_after, file_content)

	# Build cache data for this specific analysis type
	var data := {
		"paragraph_hash": paragraph_hash,
		"original_text": paragraph,
		"cached_at": Time.get_unix_time_from_system()
	}

	# Add analysis-specific fields
	match analysis_type:
		EventBus.AnalysisType.GRAMMAR:
			data["corrected"] = result.get("corrected", paragraph)
			data["explanation"] = result.get("explanation", "")
			data["llm_model"] = result.get("model", "unknown")
		EventBus.AnalysisType.STYLE:
			data["enhanced"] = result.get("enhanced", paragraph)
			data["explanation"] = result.get("explanation", "")
			data["llm_model"] = result.get("model", "unknown")
		EventBus.AnalysisType.STRUCTURE:
			data["suggestion"] = result.get("suggestion", "")
			data["explanation"] = result.get("explanation", "")
			data["llm_model"] = result.get("model", "unknown")

	# Store in the appropriate memory cache
	match analysis_type:
		EventBus.AnalysisType.GRAMMAR:
			grammar_cache[paragraph_hash] = data
		EventBus.AnalysisType.STYLE:
			style_cache[paragraph_hash] = data
		EventBus.AnalysisType.STRUCTURE:
			structure_cache[paragraph_hash] = data

	# Append to the appropriate JSONL file
	# Determine file path for cache location
	var actual_file_path := file_path
	if actual_file_path == "" and file_content != "":
		# Try to infer from current_file_path
		actual_file_path = current_file_path

	var cache_dir := _get_cache_dir_for_file(actual_file_path) if actual_file_path != "" else ".snorfeld/paragraph"
	if not FileUtils.dir_exists(cache_dir):
		_create_cache_directory(cache_dir)

	# Use separate JSONL file for each analysis type
	var jsonl_filename: String
	match analysis_type:
		EventBus.AnalysisType.GRAMMAR:
			jsonl_filename = GRAMMAR_JSONL_FILENAME
		EventBus.AnalysisType.STYLE:
			jsonl_filename = STYLE_JSONL_FILENAME
		EventBus.AnalysisType.STRUCTURE:
			jsonl_filename = STRUCTURE_JSONL_FILENAME

	var jsonl_path := cache_dir.path_join(jsonl_filename)
	var file = FileAccess.open(jsonl_path, FileAccess.READ_WRITE)
	if file:
		file.seek_end()
		file.store_string(JsonUtils.stringify_json(data) + "\n")
		file.close()
	else:
		# File doesn't exist yet, create it
		FileUtils.write_file(jsonl_path, JsonUtils.stringify_json(data) + "\n")


# Queue all paragraphs from BookService for all analysis types
func queue_all_paragraphs_for_cache() -> void:
	_queue_all_for_type(EventBus.AnalysisType.GRAMMAR)
	_queue_all_for_type(EventBus.AnalysisType.STYLE)
	_queue_all_for_type(EventBus.AnalysisType.STRUCTURE)


# Queue all paragraphs for a specific analysis type
func _queue_all_for_type(analysis_type: int) -> void:
	var all_files := BookService.get_all_files()
	for file_path in all_files:
		var file_data := BookService.get_file(file_path)
		if file_data.is_empty():
			continue
		var content = file_data.get("content", "")
		if content == "":
			continue

		# Get paragraphs from BookService
		var para_ids := BookService.get_paragraphs_for_file(file_path)
		for para_id in para_ids:
			var para_data = BookService.get_paragraph(para_id)
			var para_hash = para_data.get("hash", "")
			var para_text = para_data.get("text", "")

			if not _is_cached(para_hash, analysis_type) and not _is_queued(para_hash, analysis_type):
				_add_to_queued_keys(para_hash, analysis_type)
				_queue_task(para_hash, para_text, content, file_path, analysis_type)
				_emit_queue_updated()

	if not processing:
		_processing_start()


# Queue paragraphs from a specific file for all analysis types
func queue_file_paragraphs_for_cache(file_path: String) -> void:
	_queue_file_for_type(file_path, EventBus.AnalysisType.GRAMMAR)
	_queue_file_for_type(file_path, EventBus.AnalysisType.STYLE)
	_queue_file_for_type(file_path, EventBus.AnalysisType.STRUCTURE)


# Queue paragraphs from a specific file for a specific analysis type
func _queue_file_for_type(file_path: String, analysis_type: int) -> void:
	var file_data := BookService.get_file(file_path)
	if file_data.is_empty():
		return
	var content = file_data.get("content", "")
	if content == "":
		return

	# Get paragraphs from BookService
	var para_ids := BookService.get_paragraphs_for_file(file_path)
	for para_id in para_ids:
		var para_data = BookService.get_paragraph(para_id)
		var para_hash = para_data.get("hash", "")
		var para_text = para_data.get("text", "")

		if not _is_cached(para_hash, analysis_type) and not _is_queued(para_hash, analysis_type):
			_add_to_queued_keys(para_hash, analysis_type)
			_queue_task(para_hash, para_text, content, file_path, analysis_type)
			_emit_queue_updated()

	if not processing:
		_processing_start()


# Check if a paragraph is queued for a specific analysis type
func _is_queued(paragraph_hash: String, analysis_type: int) -> bool:
	match analysis_type:
		EventBus.AnalysisType.GRAMMAR:
			return queued_keys_grammar.has(paragraph_hash)
		EventBus.AnalysisType.STYLE:
			return queued_keys_style.has(paragraph_hash)
		EventBus.AnalysisType.STRUCTURE:
			return queued_keys_structure.has(paragraph_hash)
	return false


# Add to queued keys for a specific analysis type
func _add_to_queued_keys(paragraph_hash: String, analysis_type: int) -> void:
	match analysis_type:
		EventBus.AnalysisType.GRAMMAR:
			queued_keys_grammar[paragraph_hash] = true
		EventBus.AnalysisType.STYLE:
			queued_keys_style[paragraph_hash] = true
		EventBus.AnalysisType.STRUCTURE:
			queued_keys_structure[paragraph_hash] = true


# Queue a specific paragraph for caching (priority)
func _queue_task(paragraph_hash: String, paragraph: String, file_content: String, file_path: String = "", analysis_type: int = 0, priority: bool = false) -> void:
	queue_mutex.lock()
	var task = {"hash": paragraph_hash, "paragraph": paragraph, "file_content": file_content, "file_path": file_path, "analysis_type": analysis_type}
	if priority:
		task_queue.insert(0, task)
	else:
		task_queue.append(task)
	queue_mutex.unlock()
	_emit_queue_updated()

	# If already processing, just return - the processing loop will pick up new tasks
	if processing:
		return

	# Otherwise start processing
	_processing_start()


func _on_priority_analysis_requested(file_path: String, line_number: int, analysis_type: int) -> void:
	# Get paragraph from BookService
	var para_data: Dictionary = BookService.get_paragraph_at_line(file_path, line_number)
	if para_data.is_empty():
		return

	var paragraph_hash: String = para_data.get("hash", "")
	var paragraph: String = para_data.get("text", "")

	# Check if already cached for this analysis type
	if _is_cached(paragraph_hash, analysis_type):
		return

	# Check if already queued for this analysis type
	if _is_queued(paragraph_hash, analysis_type):
		# Remove from queue to re-queue with priority
		_remove_task_from_queue(paragraph_hash, analysis_type)

	# Get file content from BookService
	var file_data := BookService.get_file(file_path)
	var file_content := ""
	if not file_data.is_empty():
		file_content = file_data.get("content", "")

	_add_to_queued_keys(paragraph_hash, analysis_type)
	_queue_task(paragraph_hash, paragraph, file_content, file_path, analysis_type, true)


# Remove a task from the queue by paragraph_hash and analysis_type
func _remove_task_from_queue(paragraph_hash: String, analysis_type: int) -> void:
	queue_mutex.lock()
	var new_queue := []
	for task in task_queue:
		if task["hash"] == paragraph_hash and task.get("analysis_type", 0) == analysis_type:
			continue
		new_queue.append(task)
	task_queue = new_queue
	queue_mutex.unlock()


func _on_folder_opened(path: String) -> void:
	var cache_dir := path.path_join(".snorfeld").path_join(PARAGRAPH_DIR_NAME)
	if FileUtils.dir_exists(cache_dir):
		# Ensure cache is loaded before cleanup
		_ensure_cache_loaded(cache_dir)
		EventBus.cache_cleanup_started.emit()
		var removed_count := _cleanup_unused_cache_files(cache_dir, path)
		EventBus.cache_cleanup_completed.emit(removed_count)


func _on_project_loaded(path: String) -> void:
	# Load cache for this project
	var cache_dir := path.path_join(".snorfeld").path_join(PARAGRAPH_DIR_NAME)
	_ensure_cache_loaded(cache_dir)


func _on_project_unloaded() -> void:
	# Clear in-memory caches when project is unloaded
	grammar_cache.clear()
	style_cache.clear()
	structure_cache.clear()
	loaded_cache_dirs.clear()
	queued_keys_grammar.clear()
	queued_keys_style.clear()
	queued_keys_structure.clear()


func _on_run_all_analyses() -> void:
	queue_all_paragraphs_for_cache()


func _on_file_selected(path: String) -> void:
	current_file_path = path


func _on_run_chapter_analyses() -> void:
	if current_file_path == "":
		return
	queue_file_paragraphs_for_cache(current_file_path)


# Get cached grammar analysis for a paragraph by its hash
func get_grammar_cache(paragraph_hash: String) -> Dictionary:
	return grammar_cache.get(paragraph_hash, {})


# Get cached style analysis for a paragraph by its hash
func get_style_cache(paragraph_hash: String) -> Dictionary:
	return style_cache.get(paragraph_hash, {})


# Get cached structure analysis for a paragraph by its hash
func get_structure_cache(paragraph_hash: String) -> Dictionary:
	return structure_cache.get(paragraph_hash, {})


# Backward compatibility: get any cache (checks all types)
func get_paragraph_cache(paragraph_hash: String, _file_path: String = "") -> Dictionary:
	if grammar_cache.has(paragraph_hash):
		return grammar_cache[paragraph_hash]
	if style_cache.has(paragraph_hash):
		return style_cache[paragraph_hash]
	if structure_cache.has(paragraph_hash):
		return structure_cache[paragraph_hash]
	return {}


# Clean up cache entries that don't exist in the project anymore
func _cleanup_unused_cache_files(cache_path: String, _project_path: String) -> int:
	# Use BookService to check which paragraphs still exist
	var removed_count := 0

	# Clean up all 3 cache types
	removed_count += _cleanup_cache_file(cache_path, GRAMMAR_JSONL_FILENAME, grammar_cache, queued_keys_grammar)
	removed_count += _cleanup_cache_file(cache_path, STYLE_JSONL_FILENAME, style_cache, queued_keys_style)
	removed_count += _cleanup_cache_file(cache_path, STRUCTURE_JSONL_FILENAME, structure_cache, queued_keys_structure)

	return removed_count


# Clean up a single cache file
func _cleanup_cache_file(cache_path: String, filename: String, cache_dict: Dictionary, queued_dict: Dictionary) -> int:
	var removed_count := 0
	var cache_file_path := cache_path.path_join(filename)
	if not FileUtils.file_exists(cache_file_path):
		return 0

	var content := FileUtils.read_file(cache_file_path)
	var lines := content.split("\n")
	var hashes_in_cache := []

	for line in lines:
		line = line.strip_edges()
		if line == "":
			continue
		var data := JsonUtils.parse_json(line)
		if data != null and not data.is_empty():
			var para_hash = data.get("paragraph_hash", "")
			if para_hash != "":
				hashes_in_cache.append(para_hash)

	# Check which hashes are still in the project using BookService
	for para_hash in hashes_in_cache:
		if not BookService.has_paragraph(para_hash):
			cache_dict.erase(para_hash)
			queued_dict.erase(para_hash)
			removed_count += 1

	# Rewrite the JSONL file
	_rewrite_jsonl_file(cache_path, filename, cache_dict)

	return removed_count


# Rewrite a JSONL file for a cache directory from current memory state
func _rewrite_jsonl_file(cache_dir: String, filename: String, cache_dict: Dictionary) -> void:
	var jsonl_path := cache_dir.path_join(filename)
	var content := ""
	# Write all entries that belong to this cache dictionary
	for para_hash in cache_dict:
		var data = cache_dict[para_hash]
		content += JsonUtils.stringify_json(data) + "\n"
	FileUtils.write_file(jsonl_path, content)


# Rewrite all JSONL files for a cache directory
func _rewrite_all_jsonl_files(cache_dir: String) -> void:
	_rewrite_jsonl_file(cache_dir, GRAMMAR_JSONL_FILENAME, grammar_cache)
	_rewrite_jsonl_file(cache_dir, STYLE_JSONL_FILENAME, style_cache)
	_rewrite_jsonl_file(cache_dir, STRUCTURE_JSONL_FILENAME, structure_cache)


# Creates an MD5 hash from a paragraph string
func _hash_paragraph(paragraph: String) -> String:
	var hash_ctx := HashingContext.new()
	hash_ctx.start(HashingContext.HASH_MD5)
	hash_ctx.update(paragraph.to_utf8_buffer())
	return hash_ctx.finish().hex_encode()
