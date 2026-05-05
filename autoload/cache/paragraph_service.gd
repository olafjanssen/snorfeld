extends ContentCache
# Paragraph service - handles caching and analysis of paragraph results
# Uses JSONL format with in-memory cache for efficiency

const PARAGRAPH_DIR_NAME := "paragraph"
const JSONL_FILENAME := "paragraphs.jsonl"

# In-memory cache: key = "%s:%s" % [cache_dir, paragraph_hash], value = cache data
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


# Override: Get cache subdirectory name
func _get_cache_subdir() -> String:
	return PARAGRAPH_DIR_NAME


# Override: Process a single task
func _process_task(task: Dictionary):
	var cache_dir: String = task["cache_dir"]
	var paragraph_hash: String = task["hash"]

	# Ensure this directory's cache is loaded into memory
	_ensure_cache_loaded(cache_dir)

	# Check if already cached
	var key := _make_cache_key(cache_dir, paragraph_hash)
	if memory_cache.has(key):
		return

	var paragraph = task.get("paragraph", "")
	var file_content = task.get("file_content", "")
	await _create_and_store_cache(cache_dir, paragraph_hash, paragraph, file_content)
	queued_keys.erase(key)


# Override: Emit queue updated signal
func _emit_queue_updated() -> void:
	EventBus.cache_queue_updated.emit(task_queue.size(), processing)


# Override: Emit task started signal
func _emit_task_started(remaining: int) -> void:
	EventBus.cache_task_started.emit(remaining)


# Override: Emit task completed signal
func _emit_task_completed(remaining: int) -> void:
	EventBus.cache_task_completed.emit(remaining)


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
			var key := _make_cache_key(cache_dir, paragraph_hash)
			memory_cache[key] = data


# Create cache key from directory and hash
func _make_cache_key(cache_dir: String, paragraph_hash: String) -> String:
	return "%s:%s" % [cache_dir, paragraph_hash]


# Get cache directory for a file path
func _get_cache_dir_for_file(file_path: String) -> String:
	return file_path.get_base_dir().path_join(".snorfeld").path_join(PARAGRAPH_DIR_NAME)





# Creates cache entry and stores in memory + appends to JSONL file
func _create_and_store_cache(cache_dir: String, paragraph_hash: String, paragraph: String, file_content: String) -> void:
	# Ensure directory exists
	if not FileUtils.dir_exists(cache_dir):
		_create_cache_directory(cache_dir)

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

	# Store in memory (overwrite null placeholder if present)
	var key := _make_cache_key(cache_dir, paragraph_hash)
	memory_cache[key] = data

	# Append to JSONL file
	var jsonl_path := cache_dir.path_join(JSONL_FILENAME)
	var file = FileAccess.open(jsonl_path, FileAccess.READ_WRITE)
	if file:
		file.seek_end()
		file.store_string(JsonUtils.stringify_json(data) + "\n")
		file.close()
	else:
		# File doesn't exist yet, create it
		FileUtils.write_file(jsonl_path, JsonUtils.stringify_json(data) + "\n")


# Handle file scanned event - queue paragraphs for caching
func queue_paragraphs_for_cache(file_path: String, paragraphs: Array, file_content: String = "") -> void:
	var cache_dir := _get_cache_dir_for_file(file_path)

	# Ensure cache directory exists
	if not FileUtils.dir_exists(cache_dir):
		_create_cache_directory(cache_dir)

	# Ensure this directory's cache is loaded
	_ensure_cache_loaded(cache_dir)

	# Queue tasks for each paragraph
	for paragraph in paragraphs:
		var paragraph_hash := _hash_paragraph(paragraph)
		var key := _make_cache_key(cache_dir, paragraph_hash)

		# Only queue if not already in memory cache or queued
		if not memory_cache.has(key) and not queued_keys.has(key):
			queued_keys[key] = true
			_queue_task(cache_dir, paragraph_hash, paragraph, file_content, false)
			_emit_queue_updated()

	# Start processing if not already running
	if not processing:
		_processing_start()


# Remove a task from the queue by cache_dir and paragraph_hash
func _remove_task_from_queue(cache_dir: String, paragraph_hash: String) -> void:
	queue_mutex.lock()
	var key := _make_cache_key(cache_dir, paragraph_hash)
	var new_queue := []
	for task in task_queue:
		if task["cache_dir"] == cache_dir and task["hash"] == paragraph_hash:
			# Skip this task - it will be re-queued with priority
			continue
		new_queue.append(task)
	task_queue = new_queue
	queued_keys.erase(key)
	queue_mutex.unlock()


# Queue a task for paragraph cache creation
func _queue_task(cache_dir: String, paragraph_hash: String, paragraph: String, file_content: String, priority: bool = false) -> void:
	queue_mutex.lock()
	var task = {"cache_dir": cache_dir, "hash": paragraph_hash, "paragraph": paragraph, "file_content": file_content}
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


func _on_priority_cache_requested(paragraph_hash: String, file_path: String, paragraph: String, file_content: String) -> void:
	var cache_dir := _get_cache_dir_for_file(file_path)
	_ensure_cache_loaded(cache_dir)
	if not FileUtils.dir_exists(cache_dir):
		_create_cache_directory(cache_dir)
	var key := _make_cache_key(cache_dir, paragraph_hash)

	# If already cached, skip
	if memory_cache.has(key):
		return

	# If already queued, promote it to priority by removing and re-queuing
	if queued_keys.has(key):
		_remove_task_from_queue(cache_dir, paragraph_hash)

	queued_keys[key] = true
	_queue_task(cache_dir, paragraph_hash, paragraph, file_content, true)


func _on_folder_opened(path: String) -> void:
	var cache_dir := path.path_join(".snorfeld").path_join(PARAGRAPH_DIR_NAME)
	if FileUtils.dir_exists(cache_dir):
		# Ensure cache is loaded before cleanup
		_ensure_cache_loaded(cache_dir)
		EventBus.cache_cleanup_started.emit()
		var removed_count := _cleanup_unused_cache_files(cache_dir, path)
		EventBus.cache_cleanup_completed.emit(removed_count)


func _on_run_all_analyses() -> void:
	# Queue all paragraphs from all text files in the project
	var project_path := ProjectState.get_current_path()
	if project_path == "":
		return
	var text_files := FileUtils.get_all_text_files(project_path)
	for file_path in text_files:
		var content := FileUtils.read_file(file_path)
		if content != "":
			var paragraphs := content.split("\n\n")
			queue_paragraphs_for_cache(file_path, paragraphs, content)


func _on_file_selected(path: String) -> void:
	current_file_path = path
	current_file_content = FileUtils.read_file(path)


func _on_run_chapter_analyses() -> void:
	if current_file_path == "":
		return
	var paragraphs := current_file_content.split("\n\n")
	queue_paragraphs_for_cache(current_file_path, paragraphs, current_file_content)


# Get cached data for a paragraph by its hash
func get_paragraph_cache(paragraph_hash: String, file_path: String) -> Dictionary:
	var cache_dir := _get_cache_dir_for_file(file_path)
	_ensure_cache_loaded(cache_dir)
	var key := _make_cache_key(cache_dir, paragraph_hash)
	return memory_cache.get(key, {})


# Clean up cache entries that don't have corresponding source files in the project
func _cleanup_unused_cache_files(cache_path: String, project_path: String) -> int:
	# Already ensured cache is loaded by caller
	var removed_count := 0
	var project_files := FileUtils.get_all_text_files(project_path)

	# Identify entries to remove from this cache_dir
	var keys_to_remove := []
	for key in memory_cache:
		if not key.begins_with(cache_path + ":"):
			continue
		var paragraph_hash = key.substr(cache_path.length() + 1)
		if not _is_paragraph_in_project(paragraph_hash, project_files):
			keys_to_remove.append(key)
			removed_count += 1

	# Remove from memory
	for key in keys_to_remove:
		memory_cache.erase(key)

	# Rewrite the JSONL file for this cache_dir from current memory state
	_rewrite_jsonl_file(cache_path)

	return removed_count


# Rewrite the JSONL file for a cache directory from current memory state
func _rewrite_jsonl_file(cache_dir: String) -> void:
	var jsonl_path := cache_dir.path_join(JSONL_FILENAME)
	var content := ""
	for key in memory_cache:
		if key.begins_with(cache_dir + ":"):
			var data = memory_cache[key]
			content += JsonUtils.stringify_json(data) + "\n"
	FileUtils.write_file(jsonl_path, content)


# Check if a paragraph exists in any project file
func _is_paragraph_in_project(paragraph_hash: String, project_files: Array) -> bool:
	for file_path in project_files:
		var file := FileAccess.open(file_path, FileAccess.READ)
		if file:
			var content := file.get_as_text()
			file.close()
			var paragraphs := content.split("\n\n")
			for paragraph in paragraphs:
				if _hash_paragraph(paragraph.strip_edges()) == paragraph_hash:
					return true
	return false


# Creates an MD5 hash from a paragraph string
func _hash_paragraph(paragraph: String) -> String:
	var hash_ctx := HashingContext.new()
	hash_ctx.start(HashingContext.HASH_MD5)
	hash_ctx.update(paragraph.to_utf8_buffer())
	return hash_ctx.finish().hex_encode()
