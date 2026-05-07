extends AnalysisService
# Embedding service - handles caching of embedding vectors for paragraphs and chapters
# Uses JSONL format with in-memory cache for efficiency

# gdlint:ignore-file:file-length,long-function,magic-number,long-line,too-many-params,deep-nesting,high-complexity

const EMBEDDING_DIR_NAME := "embeddings"
const PARAGRAPH_JSONL_FILENAME := "paragraph_embeddings.jsonl"
const CHAPTER_JSONL_FILENAME := "chapter_embeddings.jsonl"

func _ready() -> void:
	# Configure service properties
	service_name = "embedding"
	cache_subdir = EMBEDDING_DIR_NAME
	# EmbeddingService uses a special cache filename that we'll override per-file type
	cache_filename = "embeddings.jsonl"

	# Configure field encoding for embedding vector
	field_encoders = {
		"embedding": Marshalls.variant_to_base64
	}
	field_decoders = {
		"embedding": Marshalls.base64_to_variant
	}

	# Call parent _ready for base signal connections
	# Base class connects: priority_analysis, project_loaded, project_unloaded
	super()

	# Connect service-specific signals
	CommandBus.start_analysis.connect(_on_start_analysis)
	EventBus.folder_opened.connect(_on_folder_opened)
	EventBus.file_selected.connect(_on_file_selected)


## ============================================================================
## Cache Key Management
## ============================================================================

# Override: Get cache key from payload
# For embeddings, key includes whether it's a chapter or paragraph
func _get_cache_key(payload: Dictionary) -> String:
	var text_hash: String = payload.get("hash", "")
	var is_chapter: bool = payload.get("is_chapter", false)
	var cache_dir: String = payload.get("cache_dir", "")

	if cache_dir != "":
		var prefix := "chapter" if is_chapter else "paragraph"
		return "%s:%s:%s" % [cache_dir, prefix, text_hash]
	return text_hash


# Override: Get cache key from loaded data
func _get_cache_key_from_data(data: Dictionary) -> String:
	var text_hash: String = data.get("text_hash", "")
	var is_chapter: bool = data.get("is_chapter", false)
	var cache_dir: String = data.get("cache_dir", "")

	if cache_dir != "":
		var prefix := "chapter" if is_chapter else "paragraph"
		return "%s:%s:%s" % [cache_dir, prefix, text_hash]

	# Fallback
	if data.has("text_hash"):
		return data["text_hash"]
	return ""


# Get the cache directory for a file path
func _get_cache_dir_for_file(file_path: String) -> String:
	return file_path.get_base_dir().path_join(".snorfeld").path_join(EMBEDDING_DIR_NAME)


# Create cache key from directory, hash, and whether it's a chapter
func _make_cache_key(cache_dir: String, text_hash: String, is_chapter: bool) -> String:
	var prefix := "chapter" if is_chapter else "paragraph"
	return "%s:%s:%s" % [cache_dir, prefix, text_hash]


## ============================================================================
## Override JSONL methods to handle separate files for paragraphs and chapters
## ============================================================================

# Override: Load JSONL cache - loads both paragraph and chapter files
func _load_jsonl_cache(cache_dir: String) -> void:
	_load_paragraph_jsonl_cache(cache_dir)
	_load_chapter_jsonl_cache(cache_dir)


# Load paragraph embeddings JSONL cache file into memory
func _load_paragraph_jsonl_cache(cache_dir: String) -> void:
	var jsonl_path := cache_dir.path_join(PARAGRAPH_JSONL_FILENAME)
	if not FileUtils.file_exists(jsonl_path):
		return

	var content: String = FileUtils.read_file(jsonl_path)
	var lines: Array = content.split("\n")
	for line in lines:
		line = line.strip_edges()
		if line == "":
			continue
		var data: Dictionary = JsonUtils.parse_json(line)
		if data == null or data.is_empty():
			continue
		var text_hash: String = data.get("text_hash", "")
		if text_hash != "":
			# Create key for paragraph
			var key: String = _make_cache_key(cache_dir, text_hash, false)
			var decoded_data: Dictionary = _decode_data(data)
			memory_cache[key] = decoded_data


# Load chapter embeddings JSONL cache file into memory
func _load_chapter_jsonl_cache(cache_dir: String) -> void:
	var jsonl_path := cache_dir.path_join(CHAPTER_JSONL_FILENAME)
	if not FileUtils.file_exists(jsonl_path):
		return

	var content: String = FileUtils.read_file(jsonl_path)
	var lines: Array = content.split("\n")
	for line in lines:
		line = line.strip_edges()
		if line == "":
			continue
		var data: Dictionary = JsonUtils.parse_json(line)
		if data == null or data.is_empty():
			continue
		var text_hash: String = data.get("text_hash", "")
		if text_hash != "":
			# Create key for chapter
			var key: String = _make_cache_key(cache_dir, text_hash, true)
			var decoded_data: Dictionary = _decode_data(data)
			memory_cache[key] = decoded_data


# Override: Save to JSONL - saves to appropriate file based on is_chapter flag
func _save_to_jsonl(cache_dir: String, data: Dictionary) -> void:
	if not FileUtils.dir_exists(cache_dir):
		_create_cache_directory(cache_dir)

	var is_chapter: bool = data.get("is_chapter", false)
	var jsonl_filename := PARAGRAPH_JSONL_FILENAME if not is_chapter else CHAPTER_JSONL_FILENAME
	var jsonl_path := cache_dir.path_join(jsonl_filename)

	var encoded_data = _encode_data(data)

	var file: FileAccess = FileAccess.open(jsonl_path, FileAccess.READ_WRITE)
	if file:
		file.seek_end()
		file.store_string(JsonUtils.stringify_json(encoded_data) + "\n")
		file.close()
	else:
		# File doesn't exist yet, create it
		FileUtils.write_file(jsonl_path, JsonUtils.stringify_json(encoded_data) + "\n")


# Override: Rewrite JSONL file - rewrites both files
func _rewrite_jsonl_file(cache_dir: String) -> void:
	_rewrite_jsonl_files(cache_dir)


# Rewrite the JSONL files for a cache directory from current memory state
func _rewrite_jsonl_files(cache_dir: String) -> void:
	# Rewrite paragraph embeddings file
	var paragraph_content: String = ""
	for key in memory_cache:
		if key.begins_with(cache_dir + ":paragraph:"):
			var data: Dictionary = memory_cache[key].duplicate()
			data = _encode_data(data)
			paragraph_content += JsonUtils.stringify_json(data) + "\n"
	FileUtils.write_file(cache_dir.path_join(PARAGRAPH_JSONL_FILENAME), paragraph_content)

	# Rewrite chapter embeddings file
	var chapter_content: String = ""
	for key in memory_cache:
		if key.begins_with(cache_dir + ":chapter:"):
			var data: Dictionary = memory_cache[key].duplicate()
			data = _encode_data(data)
			chapter_content += JsonUtils.stringify_json(data) + "\n"
	FileUtils.write_file(cache_dir.path_join(CHAPTER_JSONL_FILENAME), chapter_content)


## ============================================================================
## Analysis
## ============================================================================

# Override: Analyze a task and compute embedding
func _analyze(payload: Dictionary) -> Dictionary:
	var cache_dir: String = payload.get("cache_dir", "")
	var text_hash: String = payload.get("hash", "")
	var text: String = payload.get("text", "")
	var is_chapter: bool = payload.get("is_chapter", false)

	# Compute embedding for the text
	var embedding_model: String = AppConfig.get_embedding_model()

	var embed_result: Dictionary = await LLMClient.embed(embedding_model, text)

	if embed_result.get("error", null) != null:
		push_error("[EmbeddingService] Failed to compute embedding: %s" % embed_result.get("error", "Unknown error"))
		return {}

	if not embed_result.has("embedding") and not embed_result.has("json_data"):
		push_error("[EmbeddingService] No embedding in response")
		return {}

	# Extract embedding vector
	var embedding_vector: Array
	if embed_result.has("embedding"):
		embedding_vector = embed_result["embedding"]
	elif embed_result.has("json_data") and embed_result["json_data"].has("embedding"):
		embedding_vector = embed_result["json_data"]["embedding"]
	else:
		push_error("[EmbeddingService] Could not find embedding vector in response")
		return {}

	# Build cache data
	return {
		"text_hash": text_hash,
		"text": text,
		"embedding": embedding_vector,
		"model": embed_result.get("model", embedding_model),
		"is_chapter": is_chapter,
		"cache_dir": cache_dir,
		"cached_at": Time.get_unix_time_from_system()
	}


## ============================================================================
## Task Processing Overrides
## ============================================================================

# Override: Process a single task
func _process_task(task: Dictionary) -> void:
	var cache_dir: String = task.get("cache_dir", "")
	var text_hash: String = task.get("hash", "")
	var text: String = task.get("text", "")
	var is_chapter: bool = task.get("is_chapter", false)

	# Ensure cache is loaded
	_ensure_cache_loaded(cache_dir)

	# Check if already cached
	var key := _make_cache_key(cache_dir, text_hash, is_chapter)

	if memory_cache.has(key):
		if queued_keys.has(key):
			queued_keys.erase(key)
		return

	# Analyze using subclass implementation
	@warning_ignore("redundant_await")
	var result := await _analyze(task)

	if result == null or result.is_empty():
		if queued_keys.has(key):
			queued_keys.erase(key)
		return

	# Store in memory cache
	memory_cache[key] = result

	# Save to JSONL file
	_save_to_jsonl(cache_dir, result)

	# Clean up queue tracking
	if queued_keys.has(key):
		queued_keys.erase(key)


# Override: Emit queue updated signal
func _emit_queue_updated() -> void:
	EventBus.analysis_queue_updated.emit("embedding", task_queue.size())


# Override: Emit task started signal
func _emit_task_started(remaining: int) -> void:
	EventBus.analysis_task_started.emit("embedding", remaining)


# Override: Emit task completed signal
func _emit_task_completed(remaining: int) -> void:
	EventBus.analysis_task_completed.emit("embedding", remaining)


# Override: Clean up cache entries that don't have corresponding source files
func _cleanup_unused_cache_files(cache_path: String, project_path: String) -> int:
	# Get valid hashes from BookService
	var valid_paragraph_hashes := BookService.get_all_paragraph_hashes()
	var valid_chapter_hashes := BookService.get_all_chapter_hashes()

	# Convert to sets for faster lookup
	var valid_paragraph_set := {}
	for content_hash in valid_paragraph_hashes:
		valid_paragraph_set[content_hash] = true
	var valid_chapter_set := {}
	for content_hash in valid_chapter_hashes:
		valid_chapter_set[content_hash] = true

	# Remove cache entries that don't have corresponding source
	var keys_to_remove := []
	for key in memory_cache:
		# Parse key format: cache_dir:paragraph:text_hash or cache_dir:chapter:text_hash
		var parts: Array = key.split(":")
		if parts.size() >= 3:
			var is_chapter: bool = parts[1] == "chapter"
			var text_hash: String = parts[2]

			if is_chapter:
				if not valid_chapter_set.has(text_hash):
					keys_to_remove.append(key)
			else:
				if not valid_paragraph_set.has(text_hash):
					keys_to_remove.append(key)

	# Remove from memory cache
	for key in keys_to_remove:
		memory_cache.erase(key)

	# Rewrite JSONL files to persist cleanup
	_rewrite_jsonl_files(cache_path)

	return keys_to_remove.size()


## ============================================================================
## Signal Handlers
## ============================================================================

func _on_folder_opened(path: String) -> void:
	var cache_dir := path.path_join(".snorfeld").path_join(EMBEDDING_DIR_NAME)
	if FileUtils.dir_exists(cache_dir):
		# Ensure cache is loaded before cleanup
		_ensure_cache_loaded(cache_dir)
		EventBus.analysis_cleanup_started.emit("embedding")
		var removed_count := _cleanup_unused_cache_files(cache_dir, path)
		EventBus.analysis_cleanup_completed.emit("embedding", removed_count)


func _on_start_analysis(service_type: String, scope: String) -> void:
	if service_type != "EMBEDDING":
		return
	if scope == "project":
		_index_project_embeddings()
	elif scope == "chapter":
		_index_chapter_embeddings()


func _index_project_embeddings() -> void:
	# Queue all paragraphs from BookService for embedding
	var all_files := BookService.get_all_files()
	all_files.sort()
	for file_path in all_files:
		var file_data := BookService.get_file(file_path)
		if file_data.is_empty():
			continue
		var content: String = file_data.get("content", "")
		if content != "":
			# Get paragraph data from BookService (includes hash)
			var para_ids := BookService.get_paragraphs_for_file(file_path)
			var paragraphs := []
			for para_id in para_ids:
				var para_data: Dictionary = BookService.get_paragraph(para_id)
				paragraphs.append(para_data)
			queue_paragraphs_for_embedding(file_path, paragraphs, content)
			# Also queue chapter-level embedding
			queue_chapter_for_embedding(file_path)


func _on_file_selected(path: String) -> void:
	current_file_path = path
	current_file_content = FileUtils.read_file(path)


func _index_chapter_embeddings() -> void:
	if current_file_path == "":
		return
	# Get content and paragraphs from BookService if available
	var file_data := BookService.get_file(current_file_path)
	var content: String = current_file_content
	if file_data.is_empty():
		if current_file_content == "":
			return
		content = current_file_content
	else:
		content = file_data.get("content", current_file_content)

	# Get paragraph data from BookService (includes hash)
	var para_ids := BookService.get_paragraphs_for_file(current_file_path)
	var paragraphs := []
	for para_id in para_ids:
		var para_data: Dictionary = BookService.get_paragraph(para_id)
		paragraphs.append(para_data)

	queue_paragraphs_for_embedding(current_file_path, paragraphs, content)
	queue_chapter_for_embedding(current_file_path)


## ============================================================================
## Queue Management
## ============================================================================

# Queue paragraphs for embedding cache
func queue_paragraphs_for_embedding(file_path: String, paragraph_data_list: Array, file_content: String = "") -> void:
	var cache_dir := _get_cache_dir_for_file(file_path)

	# Ensure cache directory exists
	if not FileUtils.dir_exists(cache_dir):
		_create_cache_directory(cache_dir)

	# Ensure this directory's cache is loaded
	_ensure_cache_loaded(cache_dir)

	# Queue tasks for each paragraph
	for para_data in paragraph_data_list:
		var paragraph_hash: String = para_data.get("hash", "")
		var paragraph_text: String = para_data.get("text", "")
		var payload: Dictionary = {
			"cache_dir": cache_dir,
			"hash": paragraph_hash,
			"text": paragraph_text,
			"is_chapter": false
		}
		queue_task(payload, false)

	# Start processing if not already running
	if not processing:
		await _processing_start()


# Queue chapter for embedding cache
func queue_chapter_for_embedding(file_path: String) -> void:
	var cache_dir := _get_cache_dir_for_file(file_path)

	# Ensure cache directory exists
	if not FileUtils.dir_exists(cache_dir):
		_create_cache_directory(cache_dir)

	# Ensure this directory's cache is loaded
	_ensure_cache_loaded(cache_dir)

	# Get file data from BookService
	var file_data := BookService.get_file(file_path)
	if file_data.is_empty():
		return

	var chapter_hash: String = file_data.get("hash", "")
	var file_content: String = file_data.get("content", "")

	var payload: Dictionary = {
		"cache_dir": cache_dir,
		"hash": chapter_hash,
		"text": file_content,
		"is_chapter": true
	}
	queue_task(payload, false)

	# Start processing if not already running
	if not processing:
		await _processing_start()


# Queue a task for embedding cache creation
func _queue_task(cache_dir: String, text_hash: String, text: String, file_content: String, is_chapter: bool, priority: bool = false) -> void:
	var payload: Dictionary = {
		"cache_dir": cache_dir,
		"hash": text_hash,
		"text": text,
		"file_content": file_content,
		"is_chapter": is_chapter
	}
	queue_task(payload, priority)


func _on_priority_embedding_cache_requested(text_hash: String, file_path: String, text: String, is_chapter: bool) -> void:
	var cache_dir := _get_cache_dir_for_file(file_path)
	_ensure_cache_loaded(cache_dir)
	if not FileUtils.dir_exists(cache_dir):
		_create_cache_directory(cache_dir)

	var payload: Dictionary = {
		"cache_dir": cache_dir,
		"hash": text_hash,
		"text": text,
		"file_content": "",
		"is_chapter": is_chapter
	}
	queue_task(payload, true)
	if not processing:
		await _processing_start()


## ============================================================================
## Public Getters
## ============================================================================

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
	var file_data := BookService.get_file(file_path)
	if file_data.is_empty():
		return {}
	var chapter_hash: String = file_data.get("hash", "")
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


# Compute embedding for a single text (convenience method)
func compute_embedding(text: String) -> Dictionary:
	var embedding_model: String = AppConfig.get_embedding_model()
	return await LLMClient.embed(embedding_model, text)
