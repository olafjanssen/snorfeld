extends ContentCache
# Embedding service - handles caching of embedding vectors for paragraphs and chapters
# Uses JSONL format with in-memory cache for efficiency

const EMBEDDING_DIR_NAME := "embeddings"
const PARAGRAPH_JSONL_FILENAME := "paragraph_embeddings.jsonl"
const CHAPTER_JSONL_FILENAME := "chapter_embeddings.jsonl"

# In-memory cache: key = cache_key, value = cache data
var memory_cache := {}
# Track which cache directories have been loaded into memory
var loaded_cache_dirs := {}
# Track which embeddings are currently queued (to prevent duplicate queuing)
var queued_keys := {}

func _ready() -> void:
	EventBus.request_priority_embedding_cache.connect(_on_priority_embedding_cache_requested)
	EventBus.folder_opened.connect(_on_folder_opened)
	EventBus.index_project_embeddings.connect(_on_index_project_embeddings)
	EventBus.index_chapter_embeddings.connect(_on_index_chapter_embeddings)
	EventBus.file_selected.connect(_on_file_selected)
	BookService.project_loaded.connect(_on_project_loaded)
	BookService.project_unloaded.connect(_on_project_unloaded)


# Override: Get cache subdirectory name
func _get_cache_subdir() -> String:
	return EMBEDDING_DIR_NAME


# Override: Process a single task
func _process_task(task: Dictionary):
	var cache_dir: String = task["cache_dir"]
	var text_hash: String = task["hash"]
	var text: String = task.get("text", "")
	var is_chapter: bool = task.get("is_chapter", false)

	# Ensure this directory's cache is loaded into memory
	_ensure_cache_loaded(cache_dir)

	# Check if already cached
	var key := _make_cache_key(cache_dir, text_hash, is_chapter)
	if memory_cache.has(key):
		queued_keys.erase(key)
		return

	# Compute embedding for the text
	var embedding_model = AppConfig.get_embedding_model()

	var embed_result = await LLMClient.embed(embedding_model, text)

	if embed_result.get("error", null) != null:
		print("[EmbeddingService] ERROR: Failed to compute embedding: %s" % embed_result.get("error", "Unknown error"))
		queued_keys.erase(key)
		return

	if not embed_result.has("embedding") and not embed_result.has("json_data"):
		print("[EmbeddingService] ERROR: No embedding in response")
		queued_keys.erase(key)
		return

	# Extract embedding vector
	var embedding_vector: Array
	if embed_result.has("embedding"):
		embedding_vector = embed_result["embedding"]
	elif embed_result.has("json_data") and embed_result["json_data"].has("embedding"):
		embedding_vector = embed_result["json_data"]["embedding"]
	else:
		print("[EmbeddingService] ERROR: Could not find embedding vector in response")
		queued_keys.erase(key)
		return

	# Build cache data
	var data := {
		"text_hash": text_hash,
		"text": text,
		"embedding": embedding_vector,
		"model": embed_result.get("model", embedding_model),
		"is_chapter": is_chapter,
		"cached_at": Time.get_unix_time_from_system()
	}

	# Store in memory
	memory_cache[key] = data

	# Append to appropriate JSONL file
	var jsonl_filename := PARAGRAPH_JSONL_FILENAME if not is_chapter else CHAPTER_JSONL_FILENAME
	var jsonl_path := cache_dir.path_join(jsonl_filename)

	if not FileUtils.dir_exists(cache_dir):
		_create_cache_directory(cache_dir)

	var file = FileAccess.open(jsonl_path, FileAccess.READ_WRITE)
	if file:
		file.seek_end()
		file.store_string(JsonUtils.stringify_json(data) + "\n")
		file.close()
	else:
		# File doesn't exist yet, create it
		FileUtils.write_file(jsonl_path, JsonUtils.stringify_json(data) + "\n")

	queued_keys.erase(key)


# Override: Emit queue updated signal
func _emit_queue_updated() -> void:
	EventBus.embedding_cache_queue_updated.emit(task_queue.size(), processing)


# Override: Emit task started signal
func _emit_task_started(remaining: int) -> void:
	EventBus.embedding_cache_task_started.emit(remaining)


# Override: Emit task completed signal
func _emit_task_completed(remaining: int) -> void:
	EventBus.embedding_cache_task_completed.emit(remaining)


# Ensure a cache directory's JSONL files are loaded into memory
func _ensure_cache_loaded(cache_dir: String) -> void:
	if loaded_cache_dirs.get(cache_dir, false):
		return
	if FileUtils.dir_exists(cache_dir):
		_load_paragraph_jsonl_cache(cache_dir)
		_load_chapter_jsonl_cache(cache_dir)
	loaded_cache_dirs[cache_dir] = true


# Load paragraph embeddings JSONL cache file into memory
func _load_paragraph_jsonl_cache(cache_dir: String) -> void:
	var jsonl_path := cache_dir.path_join(PARAGRAPH_JSONL_FILENAME)
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
		var text_hash = data.get("text_hash", "")
		if text_hash != "":
			var key := _make_cache_key(cache_dir, text_hash, false)
			memory_cache[key] = data


# Load chapter embeddings JSONL cache file into memory
func _load_chapter_jsonl_cache(cache_dir: String) -> void:
	var jsonl_path := cache_dir.path_join(CHAPTER_JSONL_FILENAME)
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
		var text_hash = data.get("text_hash", "")
		if text_hash != "":
			var key := _make_cache_key(cache_dir, text_hash, true)
			memory_cache[key] = data


# Create cache key from directory, hash, and whether it's a chapter
func _make_cache_key(cache_dir: String, text_hash: String, is_chapter: bool) -> String:
	var prefix := "chapter" if is_chapter else "paragraph"
	return "%s:%s:%s" % [cache_dir, prefix, text_hash]


# Get cache directory for a file path
func _get_cache_dir_for_file(file_path: String) -> String:
	return file_path.get_base_dir().path_join(".snorfeld").path_join(EMBEDDING_DIR_NAME)



# Get embedding array from cache data
func _get_embedding_from_data(data: Dictionary) -> Array:
	if data.has("embedding"):
		return data["embedding"]
	return []


# Hash a string for cache key (MD5)
func _hash_text(text: String) -> String:
	var hash_ctx := HashingContext.new()
	hash_ctx.start(HashingContext.HASH_MD5)
	hash_ctx.update(text.to_utf8_buffer())
	return hash_ctx.finish().hex_encode()


# Queue paragraphs for embedding cache
func queue_paragraphs_for_embedding(file_path: String, paragraphs: Array, file_content: String = "") -> void:
	var cache_dir := _get_cache_dir_for_file(file_path)

	# Ensure cache directory exists
	if not FileUtils.dir_exists(cache_dir):
		_create_cache_directory(cache_dir)

	# Ensure this directory's cache is loaded
	_ensure_cache_loaded(cache_dir)

	# Queue tasks for each paragraph
	for paragraph in paragraphs:
		var paragraph_hash := _hash_text(paragraph)
		var key := _make_cache_key(cache_dir, paragraph_hash, false)

		# Only queue if not already in memory cache or queued
		if not memory_cache.has(key) and not queued_keys.has(key):
			queued_keys[key] = true
			_queue_task(cache_dir, paragraph_hash, paragraph, file_content, false, false)
			_emit_queue_updated()

	# Start processing if not already running
	if not processing:
		_processing_start()


# Queue chapter for embedding cache
func queue_chapter_for_embedding(file_path: String, file_content: String) -> void:
	var cache_dir := _get_cache_dir_for_file(file_path)

	# Ensure cache directory exists
	if not FileUtils.dir_exists(cache_dir):
		_create_cache_directory(cache_dir)

	# Ensure this directory's cache is loaded
	_ensure_cache_loaded(cache_dir)

	# Hash the full chapter content
	var chapter_hash := _hash_text(file_content)
	var key := _make_cache_key(cache_dir, chapter_hash, true)

	# Only queue if not already in memory cache or queued
	if not memory_cache.has(key) and not queued_keys.has(key):
		queued_keys[key] = true
		_queue_task(cache_dir, chapter_hash, file_content, file_content, true, true)
		_emit_queue_updated()

	# Start processing if not already running
	if not processing:
		_processing_start()


# Remove a task from the queue by cache_dir, text_hash, and is_chapter
func _remove_task_from_queue(cache_dir: String, text_hash: String, is_chapter: bool) -> void:
	queue_mutex.lock()
	var key := _make_cache_key(cache_dir, text_hash, is_chapter)
	var new_queue := []
	for task in task_queue:
		if task["cache_dir"] == cache_dir and task["hash"] == text_hash and task.get("is_chapter", false) == is_chapter:
			# Skip this task - it will be re-queued with priority
			continue
		new_queue.append(task)
	task_queue = new_queue
	queued_keys.erase(key)
	queue_mutex.unlock()


# Queue a task for embedding cache creation
func _queue_task(cache_dir: String, text_hash: String, text: String, file_content: String, is_chapter: bool, priority: bool = false) -> void:
	queue_mutex.lock()
	var task = {"cache_dir": cache_dir, "hash": text_hash, "text": text, "file_content": file_content, "is_chapter": is_chapter}
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


func _on_priority_embedding_cache_requested(text_hash: String, file_path: String, text: String, is_chapter: bool) -> void:
	var cache_dir := _get_cache_dir_for_file(file_path)
	_ensure_cache_loaded(cache_dir)
	if not FileUtils.dir_exists(cache_dir):
		_create_cache_directory(cache_dir)

	var key := _make_cache_key(cache_dir, text_hash, is_chapter)

	# If already cached, skip
	if memory_cache.has(key):
		return

	# If already queued, promote it to priority by removing and re-queuing
	if queued_keys.has(key):
		_remove_task_from_queue(cache_dir, text_hash, is_chapter)

	queued_keys[key] = true
	_queue_task(cache_dir, text_hash, text, "", is_chapter, true)


func _on_folder_opened(path: String) -> void:
	var cache_dir := path.path_join(".snorfeld").path_join(EMBEDDING_DIR_NAME)
	if FileUtils.dir_exists(cache_dir):
		# Ensure cache is loaded before cleanup
		_ensure_cache_loaded(cache_dir)
		EventBus.cache_cleanup_started.emit()
		var removed_count := _cleanup_unused_cache_files(cache_dir, path)
		EventBus.cache_cleanup_completed.emit(removed_count)


func _on_project_loaded(path: String) -> void:
	pass  # Project loaded, BookService is ready


func _on_project_unloaded() -> void:
	pass  # Project unloaded


func _on_index_project_embeddings() -> void:
	# Queue all paragraphs from BookService for embedding
	var all_files := BookService.get_all_files()
	all_files.sort()
	for file_path in all_files:
		var file_data := BookService.get_file(file_path)
		if file_data.is_empty():
			continue
		var content = file_data.get("content", "")
		if content != "":
			# Get paragraphs from BookService
			var para_ids := BookService.get_paragraphs_for_file(file_path)
			var paragraphs := []
			for para_id in para_ids:
				var para_data = BookService.get_paragraph(para_id)
				paragraphs.append(para_data.get("text", ""))
			queue_paragraphs_for_embedding(file_path, paragraphs, content)
			# Also queue chapter-level embedding
			queue_chapter_for_embedding(file_path, content)


func _on_file_selected(path: String) -> void:
	current_file_path = path
	current_file_content = FileUtils.read_file(path)


func _on_index_chapter_embeddings() -> void:
	if current_file_path == "":
		return
	# Get content and paragraphs from BookService if available
	var file_data := BookService.get_file(current_file_path)
	var content := current_file_content
	if file_data.is_empty():
		if current_file_content == "":
			return
		content = current_file_content
	else:
		content = file_data.get("content", current_file_content)

	# Get paragraphs from BookService
	var para_ids := BookService.get_paragraphs_for_file(current_file_path)
	var paragraphs := []
	for para_id in para_ids:
		var para_data = BookService.get_paragraph(para_id)
		paragraphs.append(para_data.get("text", ""))

	queue_paragraphs_for_embedding(current_file_path, paragraphs, content)
	queue_chapter_for_embedding(current_file_path, content)


# Get cached embedding for a paragraph by its hash
func get_paragraph_embedding(paragraph_hash: String, file_path: String) -> Dictionary:
	var cache_dir := _get_cache_dir_for_file(file_path)
	_ensure_cache_loaded(cache_dir)
	var key := _make_cache_key(cache_dir, paragraph_hash, false)
	return memory_cache.get(key, {})


# Get cached embedding for a chapter
func get_chapter_embedding(file_path: String) -> Dictionary:
	var cache_dir := _get_cache_dir_for_file(file_path)
	_ensure_cache_loaded(cache_dir)
	var file_content := FileUtils.read_file(file_path)
	var chapter_hash := _hash_text(file_content)
	var key := _make_cache_key(cache_dir, chapter_hash, true)
	return memory_cache.get(key, {})


# Get all paragraph embeddings for a file
func get_all_paragraph_embeddings(file_path: String) -> Array:
	var cache_dir := _get_cache_dir_for_file(file_path)
	_ensure_cache_loaded(cache_dir)
	var embeddings := []
	for key in memory_cache:
		if key.begins_with(cache_dir + ":paragraph:"):
			embeddings.append(memory_cache[key])
	return embeddings


# Clean up cache entries that don't have corresponding source files in the project
func _cleanup_unused_cache_files(cache_path: String, project_path: String) -> int:
	# Already ensured cache is loaded by caller
	var removed_count := 0
	var project_files := FileUtils.get_all_text_files(project_path)

	# Identify entries to remove from this cache_dir
	var keys_to_remove: Array = []
	for key in memory_cache:
		if not key.begins_with(cache_path + ":"):
			continue
		# Check if the source file still exists
		var parts: Array = key.split(":")
		if parts.size() >= 3:
			var is_chapter_str: String = parts[1]
			var is_chapter: bool = is_chapter_str == "chapter"
			var text_hash: String = parts[2]

			# For now, we keep all embeddings during cleanup
			# as they are tied to the directory structure
			# A more sophisticated approach would verify the actual content
			pass

	# For embeddings, we keep them all for now as they're small and tied to directories
	# Rewrite the JSONL files for this cache_dir from current memory state
	_rewrite_jsonl_files(cache_path)

	return removed_count


# Rewrite the JSONL files for a cache directory from current memory state
func _rewrite_jsonl_files(cache_dir: String) -> void:
	# Rewrite paragraph embeddings file
	var paragraph_content := ""
	for key in memory_cache:
		if key.begins_with(cache_dir + ":paragraph:"):
			var data = memory_cache[key]
			paragraph_content += JsonUtils.stringify_json(data) + "\n"
	FileUtils.write_file(cache_dir.path_join(PARAGRAPH_JSONL_FILENAME), paragraph_content)

	# Rewrite chapter embeddings file
	var chapter_content := ""
	for key in memory_cache:
		if key.begins_with(cache_dir + ":chapter:"):
			var data = memory_cache[key]
			chapter_content += JsonUtils.stringify_json(data) + "\n"
	FileUtils.write_file(cache_dir.path_join(CHAPTER_JSONL_FILENAME), chapter_content)


# Compute embedding for a single text (convenience method)
func compute_embedding(text: String) -> Dictionary:
	var embedding_model = AppConfig.get_embedding_model()
	return await LLMClient.embed(embedding_model, text)


# Compute and cache embedding for a paragraph
func compute_and_cache_paragraph_embedding(paragraph: String, file_path: String) -> Dictionary:
	var cache_dir := _get_cache_dir_for_file(file_path)
	_ensure_cache_loaded(cache_dir)

	var paragraph_hash := _hash_text(paragraph)
	var key := _make_cache_key(cache_dir, paragraph_hash, false)

	# Check if already cached
	if memory_cache.has(key):
		return memory_cache[key]

	# Compute embedding
	var result = await compute_embedding(paragraph)

	if result.get("error", null) != null:
		return {"error": result.get("error", "Unknown error")}

	if not result.has("embedding") and not result.has("json_data"):
		return {"error": "No embedding in response"}

	# Extract embedding vector
	var embedding_vector: Array
	if result.has("embedding"):
		embedding_vector = result["embedding"]
	elif result.has("json_data") and result["json_data"].has("embedding"):
		embedding_vector = result["json_data"]["embedding"]
	else:
		return {"error": "Could not find embedding vector in response"}

	# Build cache data
	var data := {
		"text_hash": paragraph_hash,
		"text": paragraph,
		"embedding": embedding_vector,
		"model": result.get("model", AppConfig.get_embedding_model()),
		"is_chapter": false,
		"cached_at": Time.get_unix_time_from_system()
	}

	# Store in memory
	memory_cache[key] = data

	# Save to file
	if not FileUtils.dir_exists(cache_dir):
		_create_cache_directory(cache_dir)

	var jsonl_path := cache_dir.path_join(PARAGRAPH_JSONL_FILENAME)
	var file = FileAccess.open(jsonl_path, FileAccess.READ_WRITE)
	if file:
		file.seek_end()
		file.store_string(JsonUtils.stringify_json(data) + "\n")
		file.close()
	else:
		FileUtils.write_file(jsonl_path, JsonUtils.stringify_json(data) + "\n")

	return data


# Compute and cache embedding for a chapter (full file content)
func compute_and_cache_chapter_embedding(file_path: String) -> Dictionary:
	var file_content := FileUtils.read_file(file_path)
	var cache_dir := _get_cache_dir_for_file(file_path)
	_ensure_cache_loaded(cache_dir)

	var chapter_hash := _hash_text(file_content)
	var key := _make_cache_key(cache_dir, chapter_hash, true)

	# Check if already cached
	if memory_cache.has(key):
		return memory_cache[key]

	# Compute embedding
	var result = await compute_embedding(file_content)

	if result.get("error", null) != null:
		return {"error": result.get("error", "Unknown error")}

	if not result.has("embedding") and not result.has("json_data"):
		return {"error": "No embedding in response"}

	# Extract embedding vector
	var embedding_vector: Array
	if result.has("embedding"):
		embedding_vector = result["embedding"]
	elif result.has("json_data") and result["json_data"].has("embedding"):
		embedding_vector = result["json_data"]["embedding"]
	else:
		return {"error": "Could not find embedding vector in response"}

	# Build cache data
	var data := {
		"text_hash": chapter_hash,
		"text": file_content,
		"embedding": embedding_vector,
		"model": result.get("model", AppConfig.get_embedding_model()),
		"is_chapter": true,
		"cached_at": Time.get_unix_time_from_system()
	}

	# Store in memory
	memory_cache[key] = data

	# Save to file
	if not FileUtils.dir_exists(cache_dir):
		_create_cache_directory(cache_dir)

	var jsonl_path := cache_dir.path_join(CHAPTER_JSONL_FILENAME)
	var file = FileAccess.open(jsonl_path, FileAccess.READ_WRITE)
	if file:
		file.seek_end()
		file.store_string(JsonUtils.stringify_json(data) + "\n")
		file.close()
	else:
		FileUtils.write_file(jsonl_path, JsonUtils.stringify_json(data) + "\n")

	return data
