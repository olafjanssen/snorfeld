extends ContentCache
# Paragraph service - handles caching and analysis of paragraph results
# Uses BookService for project content model, JSONL format with in-memory cache for efficiency

const PARAGRAPH_DIR_NAME := "paragraph"
const JSONL_FILENAME := "paragraphs.jsonl"

# In-memory cache: key = paragraph_hash, value = cache data
var memory_cache: Dictionary = {}
# Track which cache directories have been loaded into memory
var loaded_cache_dirs: Dictionary = {}
# Track which paragraphs are currently queued (to prevent duplicate queuing)
var queued_keys: Dictionary = {}

func _ready() -> void:
	EventBus.request_priority_cache.connect(_on_priority_cache_requested)
	EventBus.folder_opened.connect(_on_folder_opened)
	EventBus.run_all_analyses.connect(_on_run_all_analyses)
	EventBus.run_chapter_analyses.connect(_on_run_chapter_analyses)
	EventBus.file_selected.connect(_on_file_selected)
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

	# Check if already cached
	if memory_cache.has(paragraph_hash):
		queued_keys.erase(paragraph_hash)
		return

	await _create_and_store_cache(paragraph_hash, paragraph, file_content, file_path)
	queued_keys.erase(paragraph_hash)


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


# Ensure a cache directory's JSONL file is loaded into memory
func _ensure_cache_loaded(cache_dir: String) -> void:
	if loaded_cache_dirs.get(cache_dir, false):
		return
	if FileUtils.dir_exists(cache_dir):
		_load_jsonl_cache(cache_dir)
	loaded_cache_dirs[cache_dir] = true


# Load a JSONL cache file into memory
func _load_jsonl_cache(cache_dir: String) -> void:
	var jsonl_path := cache_dir.path_join(JSONL_FILENAME)
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
			memory_cache[paragraph_hash] = data


# Creates cache entry and stores in memory + appends to JSONL file
func _create_and_store_cache(paragraph_hash: String, paragraph: String, file_content: String, file_path: String = "") -> void:
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

	# Run analysis
	var grammar_result = await AnalysisService.analyze_grammar(paragraph, context_before, context_after)
	var style_result = await AnalysisService.analyze_style(paragraph, context_before, context_after)
	var structure_result = await AnalysisService.analyze_structure(paragraph, context_before, context_after, file_content)

	# Build cache data
	var data := {
		"paragraph_hash": paragraph_hash,
		"source": "",
		"original_text": paragraph,
		"analyses": {
			"grammar": {
				"corrected": grammar_result.get("corrected", paragraph),
				"explanation": grammar_result.get("explanation", "")
			},
			"style": {
				"enhanced": style_result.get("enhanced", paragraph),
				"explanation": style_result.get("explanation", "")
			},
			"structure": {
				"suggestion": structure_result.get("suggestion", ""),
				"explanation": structure_result.get("explanation", "")
			}
		},
		"llm_model": grammar_result.get("model", "unknown"),
		"cached_at": Time.get_unix_time_from_system()
	}

	# Store in memory
	memory_cache[paragraph_hash] = data

	# Append to JSONL file
	# Determine file path for cache location
	var actual_file_path := file_path
	if actual_file_path == "" and file_content != "":
		# Try to infer from current_file_path
		actual_file_path = current_file_path

	var cache_dir := _get_cache_dir_for_file(actual_file_path) if actual_file_path != "" else ".snorfeld/paragraph"
	if not FileUtils.dir_exists(cache_dir):
		_create_cache_directory(cache_dir)

	var jsonl_path := cache_dir.path_join(JSONL_FILENAME)
	var file = FileAccess.open(jsonl_path, FileAccess.READ_WRITE)
	if file:
		file.seek_end()
		file.store_string(JsonUtils.stringify_json(data) + "\n")
		file.close()
	else:
		# File doesn't exist yet, create it
		FileUtils.write_file(jsonl_path, JsonUtils.stringify_json(data) + "\n")


# Queue all paragraphs from BookService for caching
func queue_all_paragraphs_for_cache() -> void:
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

			if not memory_cache.has(para_hash) and not queued_keys.has(para_hash):
				queued_keys[para_hash] = true
				_queue_task(para_hash, para_text, content, file_path)
				_emit_queue_updated()

	if not processing:
		_processing_start()


# Queue paragraphs from a specific file
func queue_file_paragraphs_for_cache(file_path: String) -> void:
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

		if not memory_cache.has(para_hash) and not queued_keys.has(para_hash):
			queued_keys[para_hash] = true
			_queue_task(para_hash, para_text, content, file_path)
			_emit_queue_updated()

	if not processing:
		_processing_start()


# Queue a specific paragraph for caching (priority)
func _queue_task(paragraph_hash: String, paragraph: String, file_content: String, file_path: String = "", priority: bool = false) -> void:
	queue_mutex.lock()
	var task = {"hash": paragraph_hash, "paragraph": paragraph, "file_content": file_content, "file_path": file_path}
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


func _on_priority_cache_requested(file_path: String, line_number: int) -> void:
	# Get paragraph from BookService
	var para_data: Dictionary = BookService.get_paragraph_at_line(file_path, line_number)
	if para_data.is_empty():
		return

	var paragraph_hash: String = para_data.get("hash", "")
	var paragraph: String = para_data.get("text", "")

	# Check if already cached
	if memory_cache.has(paragraph_hash):
		return

	# Check if already queued
	if queued_keys.has(paragraph_hash):
		# Remove from queue to re-queue with priority
		_remove_task_from_queue(paragraph_hash)

	# Get file content from BookService
	var file_data := BookService.get_file(file_path)
	var file_content := ""
	if not file_data.is_empty():
		file_content = file_data.get("content", "")

	queued_keys[paragraph_hash] = true
	_queue_task(paragraph_hash, paragraph, file_content, file_path, true)


# Remove a task from the queue by paragraph_hash
func _remove_task_from_queue(paragraph_hash: String) -> void:
	queue_mutex.lock()
	var new_queue := []
	for task in task_queue:
		if task["hash"] == paragraph_hash:
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
	# Clear in-memory cache when project is unloaded
	memory_cache.clear()
	loaded_cache_dirs.clear()
	queued_keys.clear()


func _on_run_all_analyses() -> void:
	queue_all_paragraphs_for_cache()


func _on_file_selected(path: String) -> void:
	current_file_path = path


func _on_run_chapter_analyses() -> void:
	if current_file_path == "":
		return
	queue_file_paragraphs_for_cache(current_file_path)


# Get cached data for a paragraph by its hash
func get_paragraph_cache(paragraph_hash: String, file_path: String = "") -> Dictionary:
	return memory_cache.get(paragraph_hash, {})


# Clean up cache entries that don't exist in the project anymore
func _cleanup_unused_cache_files(cache_path: String, project_path: String) -> int:
	# Use BookService to check which paragraphs still exist
	var removed_count := 0

	# Get all paragraph hashes from cache files in this directory
	var cache_file_path := cache_path.path_join(JSONL_FILENAME)
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
			memory_cache.erase(para_hash)
			removed_count += 1

	# Rewrite the JSONL file
	_rewrite_jsonl_file(cache_path)

	return removed_count


# Rewrite the JSONL file for a cache directory from current memory state
func _rewrite_jsonl_file(cache_dir: String) -> void:
	var jsonl_path := cache_dir.path_join(JSONL_FILENAME)
	var content := ""
	# Write all entries that belong to this cache directory
	# For now, we write all entries - this could be optimized
	for para_hash in memory_cache:
		var data = memory_cache[para_hash]
		content += JsonUtils.stringify_json(data) + "\n"
	FileUtils.write_file(jsonl_path, content)


# Creates an MD5 hash from a paragraph string
func _hash_paragraph(paragraph: String) -> String:
	var hash_ctx := HashingContext.new()
	hash_ctx.start(HashingContext.HASH_MD5)
	hash_ctx.update(paragraph.to_utf8_buffer())
	return hash_ctx.finish().hex_encode()
