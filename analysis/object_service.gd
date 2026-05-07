extends AnalysisService
# Object service - handles caching and analysis of important objects (Chekhov's guns)
# Tracks appearance, relation with characters, thematic relevance, etc.

# gdlint:ignore-file:file-length,deep-nesting,long-function,missing-type-hint,magic-number,long-line,high-complexity

const OBJECT_DIR_NAME := "objects"

func _ready() -> void:
	# Configure service properties
	service_name = "object"
	cache_subdir = OBJECT_DIR_NAME
	cache_filename = "objects.jsonl"

	# Enable merging - same object can appear in multiple chapters
	should_merge_on_duplicate = true

	# Configure merge strategies for object fields
	merge_strategies = {
		"name": MergeUtils.MergeStrategy.REPLACE,
		"object_type": MergeUtils.MergeStrategy.ARRAY_MERGE_UNIQUE,
		"description": MergeUtils.MergeStrategy.CONCAT,
		"thematic_relevance": MergeUtils.MergeStrategy.ARRAY_MERGE_UNIQUE,
		"character_relations": MergeUtils.MergeStrategy.DICT_MERGE,
		"symbolic_meaning": MergeUtils.MergeStrategy.ARRAY_MERGE_UNIQUE,
		"aliases": MergeUtils.MergeStrategy.ARRAY_MERGE_UNIQUE,
		"appearances": MergeUtils.MergeStrategy.ARRAY_APPEND,
		"notes": MergeUtils.MergeStrategy.DICT_MERGE,
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
# For objects, the key is the MD5 hash of the canonical object name
func _get_cache_key(payload: Dictionary) -> String:
	var obj_name: String = payload.get("name", "")
	if obj_name != "":
		return _hash_object(obj_name)
	return payload.get("hash", "")


# Override: Get cache key from loaded data
func _get_cache_key_from_data(data: Dictionary) -> String:
	if data.has("name"):
		return _hash_object(data["name"])
	return ""

# Get the cache directory for a file path
func _get_cache_dir_for_file(file_path: String) -> String:
	return file_path.get_base_dir().path_join(".snorfeld").path_join(OBJECT_DIR_NAME)

# Creates an MD5 hash from an object name string
func _hash_object(object_name: String) -> String:
	return HashingUtils.hash_md5(object_name)


## ============================================================================
## Analysis
## ============================================================================

# Override: Analyze a file and extract objects
func _analyze(payload: Dictionary) -> Dictionary:
	var cache_path: String = payload.get("cache_path", "")
	var file_path: String = payload.get("file_path", "")
	var file_content: String = payload.get("file_content", "")

	# Process the task - extract objects and return cache data
	return await _extract_and_cache_objects(cache_path, file_path, file_content)


## ============================================================================
## Task Processing Overrides
## ============================================================================

# Override: Process a single task - delegates to _analyze
func _process_task(task: Dictionary) -> void:
	var result := await _analyze(task)
	if result != null and not result.is_empty():
		# The _analyze method returns data that should be cached
		# But for objects, _extract_and_cache_objects already handles saving
		pass


# Override: Emit queue updated signal
func _emit_queue_updated() -> void:
	EventBus.analysis_queue_updated.emit("object", task_queue.size())


# Override: Emit task started signal
func _emit_task_started(remaining: int) -> void:
	EventBus.analysis_task_started.emit("object", remaining)


# Override: Emit task completed signal
func _emit_task_completed(remaining: int) -> void:
	EventBus.analysis_task_completed.emit("object", remaining)


## ============================================================================
## Queue Management
## ============================================================================

# Handle file scanned event - queue objects for caching
func queue_objects_for_cache(file_path: String, file_content: String = "") -> void:
	# Get the base directory from the file path
	var cache_path: String = _get_cache_dir_for_file(file_path)

	# Ensure cache directory exists
	if not FileUtils.dir_exists(cache_path):
		_create_cache_directory(cache_path)

	# Check if already cached or queued
	var file_hash: String = HashingUtils.hash_md5(file_content)
	if is_cached(file_hash) and not should_merge_on_duplicate:
		return

	# Queue task
	var payload: Dictionary = {"cache_path": cache_path, "file_path": file_path, "file_content": file_content}
	queue_task(payload, false)


# Queue a task for object extraction and cache creation
func _queue_task(cache_path: String, file_path: String, file_content: String, priority: bool = false) -> void:
	var payload: Dictionary = {"cache_path": cache_path, "file_path": file_path, "file_content": file_content}
	queue_task(payload, priority)


func _on_priority_object_cache_requested(file_path: String, file_content: String) -> void:
	var cache_path: String = _get_cache_dir_for_file(file_path)
	if not FileUtils.dir_exists(cache_path):
		_create_cache_directory(cache_path)
	_queue_task(cache_path, file_path, file_content, true)


## ============================================================================
## Signal Handlers
## ============================================================================

func _on_folder_opened(path: String) -> void:
	var cache_path: String = path.path_join(".snorfeld").path_join(OBJECT_DIR_NAME)
	if DirAccess.dir_exists_absolute(cache_path):
		_ensure_cache_loaded(cache_path)
		EventBus.analysis_cleanup_started.emit("object")
		var removed_count: int = _cleanup_unused_cache_files(cache_path, path)
		EventBus.analysis_cleanup_completed.emit("object", removed_count)


func _on_project_loaded(_path: String) -> void:
	pass  # Project loaded, BookService is ready


func _on_project_unloaded() -> void:
	pass  # Project unloaded


func _on_start_analysis(service_type: String, scope: String) -> void:
	if service_type != "OBJECT":
		return
	if scope == "project":
		_on_run_all_object_analyses()
	elif scope == "chapter":
		_on_run_chapter_object_analyses()


func _on_run_all_object_analyses() -> void:
	# Queue all text files from BookService for object analysis
	var all_files: Array = BookService.get_all_files()
	all_files.sort()
	for file_path in all_files:
		var file_data: Dictionary = BookService.get_file(file_path)
		if file_data.is_empty():
			continue
		var content: String = file_data.get("content", "")
		if content != "":
			queue_objects_for_cache(file_path, content)


func _on_file_selected(path: String) -> void:
	current_file_path = path
	if FileAccess.file_exists(path):
		var file: FileAccess = FileAccess.open(path, FileAccess.READ)
		if file:
			current_file_content = file.get_as_text()
			file.close()


func _on_run_chapter_object_analyses() -> void:
	if current_file_path == "":
		return
	# Get content from BookService if available
	var file_data: Dictionary = BookService.get_file(current_file_path)
	if file_data.is_empty():
		if current_file_content != "":
			queue_objects_for_cache(current_file_path, current_file_content)
	else:
		queue_objects_for_cache(current_file_path, file_data.get("content", current_file_content))


## ============================================================================
## Object Extraction and Caching
## ============================================================================

# Extracts objects from file content and creates/updates cache files
func _extract_and_cache_objects(cache_path: String, file_path: String, file_content: String) -> Dictionary:
	var chapter_id: String = file_path.get_file().get_basename()
	_ensure_cache_loaded(cache_path)
	var existing_objects_json: String = _load_existing_objects_json(cache_path)

	var extraction_result: Dictionary = await _extract_objects_from_text(file_content, chapter_id, existing_objects_json)
	if not _is_valid_extraction(extraction_result):
		return {}

	for obj_data in extraction_result["objects"]:
		var obj_name: String = obj_data.get("name", "")
		if obj_name == "":
			continue
		var canonical_name: String = _get_canonical_object_name(obj_name, cache_path)
		var obj_hash: String = _hash_object(canonical_name)

		# Load existing data from memory cache
		var existing_data: Dictionary = memory_cache.get(obj_hash, {})

		# Merge with existing data and add chapter-specific fields
		var updated_data: Dictionary = _merge_object_data(existing_data, obj_data, chapter_id)

		# Store in memory cache
		memory_cache[obj_hash] = updated_data

	# Save all to JSONL
	_rewrite_jsonl_file(cache_path)

	return {"success": true, "object_count": extraction_result["objects"].size()}


func _is_valid_extraction(extraction_result: Dictionary) -> bool:
	if extraction_result == null or not extraction_result.has("objects"):
		push_error("[ObjectService] Failed to extract objects: invalid result")
		return false
	return true


func _get_canonical_object_name(obj_name: String, _cache_path: String) -> String:
	# Check for fuzzy matches with existing objects in memory cache
	var best_match_key: String = _find_matching_object_key(obj_name)
	if best_match_key != "":
		var existing_data: Dictionary = memory_cache[best_match_key]
		var canonical_name: String = existing_data.get("name", obj_name)
		# Add new alias to existing object
		if not existing_data.get("aliases", []).has(obj_name):
			var aliases: Array = existing_data.get("aliases", []).duplicate()
			if not aliases.has(obj_name):
				aliases.append(obj_name)
				existing_data["aliases"] = aliases
				memory_cache[best_match_key] = existing_data
		return canonical_name
	return obj_name


# Load all existing objects as JSON string for LLM context
func _load_existing_objects_json(cache_path: String) -> String:
	var existing_objs: Array = []
	_ensure_cache_loaded(cache_path)
	for key in memory_cache:
		var obj_data: Dictionary = memory_cache[key]
		# Create a clean version without bookkeeping fields
		var clean_obj: Dictionary = {}
		clean_obj["name"] = obj_data.get("name", "")
		if obj_data.has("object_type"):
			clean_obj["object_type"] = obj_data["object_type"]
		if obj_data.has("description"):
			clean_obj["description"] = obj_data["description"]
		if obj_data.has("thematic_relevance"):
			clean_obj["thematic_relevance"] = obj_data["thematic_relevance"]
		if obj_data.has("character_relations"):
			clean_obj["character_relations"] = obj_data["character_relations"]
		if obj_data.has("aliases"):
			clean_obj["aliases"] = obj_data["aliases"]
		existing_objs.append(clean_obj)

	if existing_objs.size() > 0:
		return JSON.stringify(existing_objs)
	return "[]"


## ============================================================================
## Merge Logic
## ============================================================================

# Merge arrays without duplicates
func _merge_arrays(existing: Array, new: Array) -> Array:
	return MergeUtils.merge_arrays_unique(existing, new)


# Merge character relations dictionaries
func _merge_character_relations(existing: Dictionary, new: Dictionary) -> Dictionary:
	return MergeUtils.merge_dictionaries(existing, new)


# Merge object data from LLM with existing data, adding chapter-specific fields
func _merge_object_data(existing_data: Dictionary, new_obj_data: Dictionary, _chapter_id: String) -> Dictionary:
	# Use the merge strategies configured in the service
	var merged = MergeUtils.merge_data_with_strategies(existing_data, new_obj_data, merge_strategies)

	# Special handling for aliases - filter out any that match the canonical name
	if merged.has("aliases") and merged.has("name"):
		var canonical_name: String = merged["name"]
		var filtered_aliases: Array = []
		for alias in merged["aliases"]:
			if alias != canonical_name:
				filtered_aliases.append(alias)
		merged["aliases"] = filtered_aliases

	return merged


## ============================================================================
## LLM Extraction
## ============================================================================

# Extract objects from text using LLM
func _extract_objects_from_text(text: String, chapter_id: String, existing_objects_json: String) -> Dictionary:
	var prompt: String = _build_object_extraction_prompt(existing_objects_json, chapter_id, text)
	var options: Dictionary = _get_llm_options()
	return await _call_llm_with_retry(prompt, options, 3)


## Build the prompt for object extraction
# gdlint:ignore-function:high-complexity
func _build_object_extraction_prompt(existing_objects_json: String, chapter_id: String, text: String) -> String:
	return """
You are a helpful writing assistant specializing in object analysis for a novel. Analyze the following chapter text.

Your task is to identify ONLY tangible objects and abstract concepts (Chekhov's guns) that appear in this chapter. DO NOT include characters, people, locations, or places.

IMPORTANT GUIDELINES:
- Be CONSISTENT: Use the EXACT same object names from existing objects when they reappear
- Be SELECTIVE: Focus ONLY on tangible physical objects (weapons, heirlooms, gifts, tools) and abstract concepts (ideas, themes, symbols). EXCLUDE all characters, people, locations, cities, countries, and place names.
- Be COMPACT: Use concise, standardized descriptions
- Be COMPLETE: Include all relevant information revealed in this chapter
- Only include items that are actually described or used in the chapter

CRITICAL: DO NOT include any of the following:
- Character names or people
- Location names (cities, towns, buildings, rooms, etc.)
- Place names of any kind
- Proper nouns that refer to people or places

Existing objects for reference:
%s

Chapter: %s

Chapter Text:
%s

For each important TANGIBLE OBJECT or ABSTRACT CONCEPT that appears in this chapter, return its complete profile:
- name: EXACT match with existing objects if they exist
- object_type: Array of type categories (e.g., ["weapon", "family heirloom", "gift", "tool", "symbol", "concept", "idea"])
- description: Physical description and purpose (for tangible objects) or definition (for concepts)
- thematic_relevance: Array of themes this object represents (e.g., ["power", "betrayal", "hope"])
- character_relations: Object of {character_name: relationship_description} (how characters interact with this object)
- symbolic_meaning: Array of symbolic meanings (e.g., ["foreshadowing", "character's fate"])
- aliases: Array of OTHER NAMES they are LITERALLY called in this chapter text
- notes: Brief description of their appearance/role in THIS chapter

IMPORTANT: Only include an alias if that exact string is used as a name for the object in this chapter. Do NOT include descriptive phrases or empty strings as aliases.

Respond with a JSON object:
{
  "objects": [
    {
      "name": "Object Name",
      "object_type": ["type1", "type2"],
      "description": "Physical description or concept definition",
      "thematic_relevance": ["theme1", "theme2"],
      "character_relations": {"CharacterName": "how they relate to it"},
      "symbolic_meaning": ["meaning1"],
      "aliases": ["Nickname"],
      "notes": "What happens with this object in this chapter"
    }
  ]
}
""" % [existing_objects_json, chapter_id, text]


## Get LLM options
func _get_llm_options() -> Dictionary:
	return {
		"temperature": AppConfig.get_llm_temperature(),
		"max_tokens": AppConfig.get_llm_max_tokens()
	}


## Call LLM with retry logic
func _call_llm_with_retry(prompt: String, options: Dictionary, max_retries: int) -> Dictionary:
	var llm_response: Dictionary = await LLMClient.generate_json(AppConfig.get_llm_model(), prompt, options)
	if llm_response.get("parsed_json", null) != null:
		return llm_response["parsed_json"]

	for _i in range(max_retries):
		if llm_response.get("done", false) == false:
			options["max_tokens"] = options.get("max_tokens", AppConfig.get_llm_max_tokens()) * 2
		llm_response = await LLMClient.generate_json(AppConfig.get_llm_model(), prompt, options)
		if llm_response.get("parsed_json", null) != null:
			return llm_response["parsed_json"]

	push_error("[ObjectService] Failed to parse object extraction response after %d retries" % max_retries)
	return {"objects": []}


## ============================================================================
## Fuzzy Matching
## ============================================================================

# Find matching object in memory cache using fuzzy matching
# Returns the object hash key if found, empty string otherwise
func _find_matching_object_key(obj_name: String) -> String:
	var best_match_key: String = ""
	var best_score: int = 0

	for key in memory_cache:
		var data: Dictionary = memory_cache[key]
		var existing_name: String = data.get("name", "")

		# Compare against the actual object name
		var score: int = HashingUtils.calculate_similarity(obj_name, existing_name)
		if score > best_score:
			best_score = score
			best_match_key = key

		# Also check aliases
		if data.has("aliases") and data["aliases"] is Array:
			for alias in data["aliases"]:
				var alias_score: int = HashingUtils.calculate_similarity(obj_name, alias)
				if alias_score > best_score:
					best_score = alias_score
					best_match_key = key
				if alias_score >= 80:
					break
			if best_score >= 80:
				break
		if best_score >= 80:
			break

	# Return match if score is above threshold
	if best_score >= 80:
		return best_match_key
	return ""


## ============================================================================
## Public Getters
## ============================================================================

# Get the object cache path for the current project
func get_cache_path() -> String:
	var project_path: String = BookService.loaded_project_path
	if project_path == "":
		project_path = "res://"
	return project_path.path_join(".snorfeld").path_join(OBJECT_DIR_NAME)


# Get all object files in the cache directory
func get_all_objects(cache_path: String) -> Array:
	var objects: Array = []
	_ensure_cache_loaded(cache_path)
	for key in memory_cache:
		objects.append(memory_cache[key])
	return objects


# Get all objects for the current project
func get_all_project_objects() -> Array:
	var cache_path: String = get_cache_path()
	return get_all_objects(cache_path)


# Get a specific object by name
func get_object(obj_name: String, cache_path: String) -> Dictionary:
	# Use MD5 hash of object name for key
	var obj_hash: String = _hash_object(obj_name)
	_ensure_cache_loaded(cache_path)

	# First try exact hash match
	if memory_cache.has(obj_hash):
		return memory_cache[obj_hash]

	# Try fuzzy match
	var matched_key: String = _find_matching_object_key(obj_name)
	if matched_key != "":
		return memory_cache[matched_key]

	return {}


## ============================================================================
## Cleanup
## ============================================================================

# Clean up object cache files that don't have corresponding source files in the project
func _cleanup_unused_cache_files(cache_path: String, project_path: String) -> int:
	var removed_count: int = 0
	var project_files: Array = FileUtils.get_all_text_files(project_path)

	var keys_to_remove: Array = []
	for key in memory_cache:
		var data: Dictionary = memory_cache[key]
		var appearances: Array = data.get("appearances", [])
		var all_missing: bool = true

		# Check if any appearance references a file that still exists
		for appearance in appearances:
			for project_file in project_files:
				if project_file.get_file().get_basename() == appearance:
					all_missing = false
					break
			if not all_missing:
				break

		if all_missing:
			keys_to_remove.append(key)
			removed_count += 1

	# Remove from memory cache
	for key in keys_to_remove:
		memory_cache.erase(key)

	# Rewrite the JSONL file
	_rewrite_jsonl_file(cache_path)

	return removed_count
