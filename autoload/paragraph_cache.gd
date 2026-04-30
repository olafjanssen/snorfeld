extends Node
# Paragraph cache management - handles caching of paragraph analysis results

const PARAGRAPH_DIR_NAME := "paragraph"

# Task queue for paragraph cache creation
var task_queue := []
var queue_mutex := Mutex.new()
var processing := false

func connect_signals() -> void:
	pass  # Signals are handled through CacheManager


# Handle file scanned event - queue paragraphs for caching
func queue_paragraphs_for_cache(file_path: String, paragraphs: Array, file_content: String = "") -> void:
	# Get the base directory from the file path
	var dir_path := file_path.get_base_dir()
	var cache_path := dir_path.path_join(".snorfeld").path_join(PARAGRAPH_DIR_NAME)

	# Ensure cache exists for this directory
	if not DirAccess.dir_exists_absolute(cache_path):
		print("[ParagraphCache] Creating cache directory: %s" % cache_path)
		_create_cache_directory(cache_path)

	# Queue tasks for each paragraph
	var queued_count := 0
	for paragraph in paragraphs:
		var paragraph_hash := _hash_paragraph_md5(paragraph)
		var cache_file_path := cache_path.path_join("%s.json" % paragraph_hash)

		# Only create if it doesn't exist
		if not _file_exists(cache_file_path):
			print("[ParagraphCache] Queuing paragraph (hash: %s, length: %d chars)" % [paragraph_hash, paragraph.length()])
			_queue_task(cache_path, paragraph_hash, paragraph, file_content)
			queued_count += 1
		else:
			print("[ParagraphCache] Paragraph already cached (hash: %s)" % paragraph_hash)

	print("[ParagraphCache] Queued %d new paragraphs for processing" % queued_count)
	# Start processing if not already running
	if not processing:
		print("[ParagraphCache] Starting processing queue")
		_processing_start()


# Queue a task for paragraph cache creation
func _queue_task(cache_path: String, paragraph_hash: String, paragraph: String, file_content: String) -> void:
	queue_mutex.lock()
	task_queue.append({"cache_path": cache_path, "hash": paragraph_hash, "paragraph": paragraph, "file_content": file_content})
	queue_mutex.unlock()
	print("[ParagraphCache] Task queued. Queue size: %d" % task_queue.size())

	# If already processing, just return - the thread will pick up new tasks
	if processing:
		print("[ParagraphCache] Already processing, task will be picked up")
		return

	# Otherwise start processing
	print("[ParagraphCache] Not processing, starting now")
	_processing_start()


# Start processing tasks
func _processing_start() -> void:
	if processing:
		print("[ParagraphCache] Processing already in progress")
		return
	print("[ParagraphCache] Starting processing")
	processing = true
	_process_next_task()


# Process next task using call_deferred to avoid blocking the main thread
func _process_next_task() -> void:
	queue_mutex.lock()
	if task_queue.is_empty():
		queue_mutex.unlock()
		print("[ParagraphCache] Queue empty, stopping processing")
		processing = false
		return

	var task: Dictionary = task_queue.pop_front()
	queue_mutex.unlock()
	print("[ParagraphCache] Processing task (hash: %s, remaining: %d)" % [task["hash"], task_queue.size()])

	# Process the task - create cache file
	var cache_file_path: String = task["cache_path"].path_join("%s.json" % task["hash"])
	if not _file_exists(cache_file_path):
		print("[ParagraphCache] Creating cache file: %s" % cache_file_path)
		_create_cache_file_and_continue(cache_file_path, task["paragraph"], task.get("file_content", ""))
	else:
		print("[ParagraphCache] Cache file already exists, skipping: %s" % cache_file_path)
		call_deferred("_process_next_task")


# Helper to create cache file and continue processing
func _create_cache_file_and_continue(cache_file_path: String, paragraph: String, file_content: String) -> void:
	print("[ParagraphCache] Calling TextAnalyzer for paragraph...")
	var success := await _create_cache_file(cache_file_path, paragraph, file_content)
	if success:
		print("[ParagraphCache] Cache file created successfully: %s" % cache_file_path)
	else:
		print("[ParagraphCache] Failed to create cache file: %s" % cache_file_path)
	# Process next task
	call_deferred("_process_next_task")


# Creates a cache file for a paragraph with analysis results
func _create_cache_file(path: String, paragraph: String, file_content: String = "") -> bool:
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

	# Use TextAnalyzer to get grammar corrections with context
	var grammar_result = await TextAnalyzer.analyze_grammar(paragraph, context_before, context_after)
	# Use TextAnalyzer to get stylistic improvements with context
	var style_result = await TextAnalyzer.analyze_style(paragraph, context_before, context_after)

	# Write cache file with original, grouped analysis results
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
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
				}
			},
			"llm_model": grammar_result.get("model", "unknown"),
			"cached_at": Time.get_unix_time_from_system()
		}
		var json_str := JSON.stringify(data)
		file.store_string(json_str)
		file.close()
		print("[ParagraphCache] Cache file written: %s" % path)
		return true
	print("[ParagraphCache] ERROR: Failed to open file for writing: %s" % path)
	return false


# Check if file exists
func _file_exists(path: String) -> bool:
	var dir := DirAccess.open(path.get_base_dir())
	if dir:
		return dir.file_exists(path.get_file())
	return false


# Creates an MD5 hash from a paragraph string
func _hash_paragraph_md5(paragraph: String) -> String:
	var hash_ctx := HashingContext.new()
	hash_ctx.start(HashingContext.HASH_MD5)
	hash_ctx.update(paragraph.to_utf8_buffer())
	var hash_bytes := hash_ctx.finish()
	return hash_bytes.hex_encode()


# Creates a folder for the given directory
func _create_cache_directory(base_path: String) -> bool:
	if not DirAccess.dir_exists_absolute(base_path):
		var err: int = DirAccess.make_dir_recursive_absolute(base_path)
		if err == OK:
			return true
		else:
			push_error("Failed to create paragraph cache directory: %s" % [base_path])
			return false
	else:
		return true


# Get cached data for a paragraph by its hash
# Returns Dictionary with cached data or null if not found
func get_paragraph_cache(paragraph_hash: String, file_path: String) -> Dictionary:
	var dir_path := file_path.get_base_dir()
	var cache_path := dir_path.path_join(".snorfeld").path_join(PARAGRAPH_DIR_NAME)
	var cache_file_path := cache_path.path_join("%s.json" % paragraph_hash)

	if _file_exists(cache_file_path):
		var file := FileAccess.open(cache_file_path, FileAccess.READ)
		if file:
			var content := file.get_as_text()
			file.close()
			var json := JSON.new()
			var parse_result := json.parse(content)
			if parse_result == OK:
				return json.get_data()
			else:
				print("[ParagraphCache] ERROR: Failed to parse cache file: %s" % cache_file_path)
		return {}
	else:
		print("[ParagraphCache] Cache not found for hash: %s" % paragraph_hash)
		return {}
