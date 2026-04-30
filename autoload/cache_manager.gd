extends Node

# Cache manager for temporary data storage
# Creates and manages the .snorfeld cache folder

const CACHE_DIR_NAME := ".snorfeld"
const PARAGRAPH_DIR_NAME := "paragraph"
var current_cache_path := ""

# Task queue for paragraph cache creation
var task_queue := []
var queue_mutex := Mutex.new()
var processing := false


func _ready() -> void:
	# Connect to folder_opened signal to auto-create cache
	GlobalSignals.folder_opened.connect(_on_folder_opened)
	# Connect to file_scanned signal to create cache files
	GlobalSignals.file_scanned.connect(_on_file_scanned)


func _on_folder_opened(path: String) -> void:
	print("[CacheManager] Folder opened: %s" % path)
	current_cache_path = path.path_join(CACHE_DIR_NAME)

	# Clear existing cache for testing purposesand create new folder
	clear_cache()

	current_cache_path = path.path_join(CACHE_DIR_NAME)
	print("[CacheManager] Cache path set to: %s" % current_cache_path)
	create_folder(current_cache_path)


func _on_file_scanned(path: String, paragraphs: Array) -> void:
	print("[CacheManager] File scanned: %s (paragraphs: %d)" % [path, paragraphs.size()])
	# Get the base directory from the file path
	var dir_path := path.get_base_dir()
	var cache_path := dir_path.path_join(CACHE_DIR_NAME).path_join(PARAGRAPH_DIR_NAME)

	# Ensure cache exists for this directory
	if not DirAccess.dir_exists_absolute(cache_path):
		print("[CacheManager] Creating cache directory: %s" % cache_path)
		create_folder(cache_path)

	# Queue tasks for each paragraph
	var queued_count := 0
	for paragraph in paragraphs:
		var paragraph_hash := _hash_paragraph_md5(paragraph)
		var cache_file_path := cache_path.path_join("%s.json" % paragraph_hash)

		# Only create if it doesn't exist
		if not _file_exists(cache_file_path):
			print("[CacheManager] Queuing paragraph (hash: %s, length: %d chars)" % [paragraph_hash, paragraph.length()])
			_queue_task(cache_path, paragraph_hash, paragraph)
			queued_count += 1
		else:
			print("[CacheManager] Paragraph already cached (hash: %s)" % paragraph_hash)

	print("[CacheManager] Queued %d new paragraphs for processing" % queued_count)
	# Start processing if not already running
	if not processing:
		print("[CacheManager] Starting processing queue")
		_processing_start()


# Queue a task for paragraph cache creation
func _queue_task(cache_path: String, paragraph_hash: String, paragraph: String) -> void:
	queue_mutex.lock()
	task_queue.append({"cache_path": cache_path, "hash": paragraph_hash, "paragraph": paragraph})
	queue_mutex.unlock()
	print("[CacheManager] Task queued. Queue size: %d" % task_queue.size())

	# If already processing, just return - the thread will pick up new tasks
	if processing:
		print("[CacheManager] Already processing, task will be picked up")
		return

	# Otherwise start processing
	print("[CacheManager] Not processing, starting now")
	_processing_start()


# Start processing tasks
func _processing_start() -> void:
	if processing:
		print("[CacheManager] Processing already in progress")
		return
	print("[CacheManager] Starting processing")
	processing = true
	_process_next_task()


# Process next task using call_deferred to avoid blocking the main thread
func _process_next_task() -> void:
	queue_mutex.lock()
	if task_queue.is_empty():
		queue_mutex.unlock()
		print("[CacheManager] Queue empty, stopping processing")
		processing = false
		return

	var task: Dictionary = task_queue.pop_front()
	queue_mutex.unlock()
	print("[CacheManager] Processing task (hash: %s, remaining: %d)" % [task["hash"], task_queue.size()])

	# Process the task - create cache file
	var cache_file_path: String = task["cache_path"].path_join("%s.json" % task["hash"])
	if not _file_exists(cache_file_path):
		print("[CacheManager] Creating cache file: %s" % cache_file_path)
		_create_cache_file_and_continue(cache_file_path, task["paragraph"])
	else:
		print("[CacheManager] Cache file already exists, skipping: %s" % cache_file_path)
		call_deferred("_process_next_task")

# Helper to create cache file and continue processing
func _create_cache_file_and_continue(cache_file_path: String, paragraph: String) -> void:
	print("[CacheManager] Calling LLM for paragraph...")
	var success := await _create_cache_file(cache_file_path, paragraph)
	if success:
		print("[CacheManager] Cache file created successfully: %s" % cache_file_path)
	else:
		print("[CacheManager] Failed to create cache file: %s" % cache_file_path)
	# Process next task
	call_deferred("_process_next_task")


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


# Creates a cache file for a paragraph with LLM-generated corrections and explanations
func _create_cache_file(path: String, paragraph: String) -> bool:
	print("[CacheManager] Generating LLM response for paragraph...")
	# First, call Ollama to get spelling/grammar corrections with explanations
	var prompt := """
You are a helpful writing assistant. Analyze the following text and provide:
1. A corrected version with improved spelling and grammar (keep the original meaning)
2. A brief explanation of the changes made

Text to analyze:
%s

Respond with a JSON object containing 'corrected' and 'explanation' fields:
{
  "corrected": "[corrected text]",
  "explanation": "[brief explanation of changes]"
}
""" % paragraph

	print("[CacheManager] Sending prompt to Ollama (length: %d chars)" % prompt.length())
	var llm_response = await OllamaClient.generate_json("qwen3.5:9b", prompt, {"temperature": 0.3, "max_tokens": 512})
	print("[CacheManager] Received Ollama response")

	var corrected_text := paragraph
	var explanation := ""

	if llm_response.get("response", null) != null:
		# The OllamaClient.generate_json already parsed the JSON for us
		var parsed = llm_response["response"]
		print("[CacheManager] Parsed JSON: corrected=%s, explanation=%s" % [parsed.get("corrected", ""), parsed.get("explanation", "")])
		if parsed is Dictionary:
			if parsed.has("corrected"):
				corrected_text = parsed["corrected"]
			if parsed.has("explanation"):
				explanation = parsed["explanation"]
	else:
		print("[CacheManager] WARNING: LLM response error or not JSON")
		if llm_response.has("error"):
			print("[CacheManager] LLM Error: %s" % llm_response["error"])

	# Write cache file with original, corrected version, and explanation
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		var data := {
			"paragraph_hash": _hash_paragraph_md5(paragraph),
			"source": "",
			"original_text": paragraph,
			"corrected_text": corrected_text,
			"explanation": explanation,
			"llm_model": "llama3",
			"cached_at": Time.get_unix_time_from_system()
		}
		var json_str := JSON.stringify(data)
		file.store_string(json_str)
		file.close()
		print("[CacheManager] Cache file written: %s" % path)
		return true
	print("[CacheManager] ERROR: Failed to open file for writing: %s" % path)
	return false


# Creates a folder for the given directory
func create_folder(base_path: String) -> bool:
	if not DirAccess.dir_exists_absolute(base_path):
		var err: int = DirAccess.make_dir_recursive_absolute(base_path)
		if err == OK:
			return true
		else:
			push_error("Failed to create cache directory: %s" % [base_path])
			return false
	else:
		return true


# Recursively removes a directory and all its contents
func _remove_directory(path: String) -> bool:
	var dir = DirAccess.open(path)
	if not dir:
		push_error("[CacheManager] Failed to open directory for removal: %s" % path)
		return false

	print("[CacheManager] Removing directory: %s" % path)
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		var full_path = path.path_join(file_name)
		if dir.current_is_dir():
			# Recursively remove subdirectory
			if not _remove_directory(full_path):
				dir.list_dir_end()
				return false
		else:
			# Remove file
			print("[CacheManager] Removing file: %s" % full_path)
			if DirAccess.remove_absolute(full_path) != OK:
				push_error("[CacheManager] Failed to remove file: %s" % full_path)
				dir.list_dir_end()
				return false
		file_name = dir.get_next()
	dir.list_dir_end()

	# Remove the now-empty directory
	print("[CacheManager] Removing empty directory: %s" % path)
	if DirAccess.remove_absolute(path) != OK:
		push_error("[CacheManager] Failed to remove directory: %s" % path)
		return false
	return true

# Clears the cache folder and all its contents
func clear_cache() -> bool:
	var cache_path := current_cache_path

	if DirAccess.dir_exists_absolute(cache_path):
		print("[CacheManager] Clearing cache at: %s" % cache_path)
		if _remove_directory(cache_path):
			current_cache_path = ""
			print("[CacheManager] Cache cleared successfully")
			return true
		else:
			push_error("[CacheManager] Failed to clear cache directory: %s" % [cache_path])
			return false
	else:
		print("[CacheManager] Cache doesn't exist, nothing to clear")
		return true


# Gets the current cache path
func get_cache_path() -> String:
	return current_cache_path
