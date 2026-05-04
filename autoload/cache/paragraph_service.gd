extends ContentCache
# Paragraph service - handles caching and analysis of paragraph results

const PARAGRAPH_DIR_NAME := "paragraph"

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
	var cache_file_path: String = task["cache_path"].path_join("%s.json" % task["hash"])
	if not _file_exists(cache_file_path):
		var paragraph = task.get("paragraph", "")
		var file_content = task.get("file_content", "")
		await _create_cache_file(cache_file_path, paragraph, file_content)


# Override: Emit queue updated signal
func _emit_queue_updated() -> void:
	EventBus.cache_queue_updated.emit(task_queue.size(), processing)


# Override: Emit task started signal
func _emit_task_started(remaining: int) -> void:
	EventBus.cache_task_started.emit(remaining)


# Override: Emit task completed signal
func _emit_task_completed(remaining: int) -> void:
	EventBus.cache_task_completed.emit(remaining)


# Handle file scanned event - queue paragraphs for caching
func queue_paragraphs_for_cache(file_path: String, paragraphs: Array, file_content: String = "") -> void:
	var dir_path := file_path.get_base_dir()
	var cache_path := dir_path.path_join(".snorfeld").path_join(PARAGRAPH_DIR_NAME)

	# Ensure cache exists for this directory
	if not FileUtils.dir_exists(cache_path):
		_create_cache_directory(cache_path)

	# Queue tasks for each paragraph
	for paragraph in paragraphs:
		var paragraph_hash := _hash_paragraph_md5(paragraph)
		var cache_file_path := cache_path.path_join("%s.json" % paragraph_hash)

		# Only create if it doesn't exist
		if not _file_exists(cache_file_path):
			# Pass file_content as full_chapter for structure analysis
			_queue_task(cache_path, paragraph_hash, paragraph, file_content)
			_emit_queue_updated()

	# Start processing if not already running
	if not processing:
		_processing_start()


# Queue a task for paragraph cache creation
func _queue_task(cache_path: String, paragraph_hash: String, paragraph: String, file_content: String, priority: bool = false) -> void:
	queue_mutex.lock()
	var task = {"cache_path": cache_path, "hash": paragraph_hash, "paragraph": paragraph, "file_content": file_content}
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
	var dir_path := file_path.get_base_dir()
	var cache_path := dir_path.path_join(".snorfeld").path_join(PARAGRAPH_DIR_NAME)
	if not FileUtils.dir_exists(cache_path):
		_create_cache_directory(cache_path)
	_queue_task(cache_path, paragraph_hash, paragraph, file_content, true)


func _on_folder_opened(path: String) -> void:
	var cache_path := path.path_join(".snorfeld").path_join(PARAGRAPH_DIR_NAME)
	if FileUtils.dir_exists(cache_path):
		EventBus.cache_cleanup_started.emit()
		var removed_count := _cleanup_unused_cache_files(cache_path, path)
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


# Creates a cache file for a paragraph with analysis results
func _create_cache_file(path: String, paragraph: String, file_content: String = "") -> void:
	# Extract context from file_content (text before and after the paragraph)
	var context_before := ""
	var context_after := ""
	if file_content.length() > 0 and paragraph.length() > 0:
		var paragraph_index := file_content.find(paragraph)
		if paragraph_index != -1:
			# Get up to 100 words before the paragraph
			var before_start = max(0, paragraph_index - 1000)  # Look back ~1000 chars for context
			context_before = file_content.substr(before_start, paragraph_index - before_start)
			# Get up to 100 words after the paragraph
			var after_start := paragraph_index + paragraph.length()
			var after_end = min(file_content.length(), after_start + 1000)
			context_after = file_content.substr(after_start, after_end - after_start)

	# Use AnalysisService to get grammar corrections with context
	var grammar_result = await AnalysisService.analyze_grammar(paragraph, context_before, context_after)
	# Use AnalysisService to get stylistic improvements with context
	var style_result = await AnalysisService.analyze_style(paragraph, context_before, context_after)
	# Use AnalysisService to get structural suggestions with full chapter context
	var structure_result = await AnalysisService.analyze_structure(paragraph, context_before, context_after, file_content)

	# Write cache file with original, grouped analysis results
	var data := {
		"paragraph_hash": _hash_paragraph_md5(paragraph),
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
	FileUtils.write_file(path, JsonUtils.stringify_json(data))


# Check if file exists
func _file_exists(path: String) -> bool:
	return FileUtils.file_exists(path)


# Creates an MD5 hash from a paragraph string
func _hash_paragraph_md5(paragraph: String) -> String:
	var hash_ctx := HashingContext.new()
	hash_ctx.start(HashingContext.HASH_MD5)
	hash_ctx.update(paragraph.to_utf8_buffer())
	var hash_bytes := hash_ctx.finish()
	return hash_bytes.hex_encode()


# Get cached data for a paragraph by its hash
# Returns Dictionary with cached data or null if not found
func get_paragraph_cache(paragraph_hash: String, file_path: String) -> Dictionary:
	var dir_path := file_path.get_base_dir()
	var cache_path := dir_path.path_join(".snorfeld").path_join(PARAGRAPH_DIR_NAME)
	var cache_file_path := cache_path.path_join("%s.json" % paragraph_hash)

	if not _file_exists(cache_file_path):
		return {}

	var content := FileUtils.read_file(cache_file_path)
	if content != "":
		return JsonUtils.parse_json(content)
	return {}


# Clean up cache files that don't have corresponding source files in the project
func _cleanup_unused_cache_files(cache_path: String, project_path: String) -> int:
	var dir := DirAccess.open(cache_path)
	if not dir:
		return 0

	var removed_count := 0
	var project_files := FileUtils.get_all_text_files(project_path)

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			var cache_file_path := cache_path.path_join(file_name)
			var cache_content := FileUtils.read_file(cache_file_path)
			if cache_content != "":
				var data := JsonUtils.parse_json(cache_content)
				if not data.is_empty():
					var source_file = data.get("source", "")
					# If no source recorded or source file doesn't exist, check if paragraph exists in any project file
					if source_file == "" or not _file_exists(source_file):
						var paragraph_hash = data.get("paragraph_hash", "")
						if not _is_paragraph_in_project(paragraph_hash, project_files):
							if DirAccess.remove_absolute(cache_file_path) == OK:
								removed_count += 1
							else:
								push_error("Failed to delete cache file: %s" % cache_file_path)
					# else: keep the file - it's still in use
				else:
					# Failed to parse - remove the corrupt cache file
					push_warning("Failed to parse cache file: %s - removing" % file_name)
					if DirAccess.remove_absolute(cache_file_path) == OK:
						removed_count += 1
			else:
					push_error("Failed to open cache file: %s" % file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

	return removed_count


func _get_all_text_files(project_path: String) -> Array:
	var text_files := []
	var dir := DirAccess.open(project_path)
	if not dir:
		return text_files

	_get_text_files_recursive(dir, project_path, text_files)
	return text_files


func _get_text_files_recursive(dir: DirAccess, base_path: String, text_files: Array) -> void:
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		var full_path := base_path.path_join(file_name)
		if dir.current_is_dir():
			# Skip .snorfeld cache directory
			if file_name != ".snorfeld":
				var sub_dir := DirAccess.open(full_path)
				if sub_dir:
					_get_text_files_recursive(sub_dir, full_path, text_files)
		else:
			# Check if it's a text file (not binary)
			if file_name.ends_with(".txt") or file_name.ends_with(".md") or file_name.ends_with(".markdown"):
				text_files.append(full_path)
		file_name = dir.get_next()
	dir.list_dir_end()


func _is_paragraph_in_project(paragraph_hash: String, project_files: Array) -> bool:
	for file_path in project_files:
		var file := FileAccess.open(file_path, FileAccess.READ)
		if file:
			var content := file.get_as_text()
			file.close()
			# Split content into paragraphs and check hashes
			var paragraphs := content.split("\n\n")
			for paragraph in paragraphs:
				if _hash_paragraph_md5(paragraph.strip_edges()) == paragraph_hash:
					return true
	return false
