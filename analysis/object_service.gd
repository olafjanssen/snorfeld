extends ContentCache
# Object service - handles caching and analysis of important objects (Chekhov's guns)
# Tracks appearance, relation with characters, thematic relevance, etc.

const OBJECT_DIR_NAME := "objects"

# Track the current file for object analysis
var current_object_file_path: String = ""
var current_object_file_content: String = ""

func _ready() -> void:
	CommandBus.start_analysis.connect(_on_start_analysis)
	EventBus.file_selected.connect(_on_file_selected)
	EventBus.folder_opened.connect(_on_folder_opened)
	if BookService != null:
		BookService.project_loaded.connect(_on_project_loaded)
		BookService.project_unloaded.connect(_on_project_unloaded)


# Override: Get cache subdirectory name
func _get_cache_subdir() -> String:
	return OBJECT_DIR_NAME

func _on_folder_opened(path: String) -> void:
	var cache_path := path.path_join(".snorfeld").path_join(OBJECT_DIR_NAME)
	if DirAccess.dir_exists_absolute(cache_path):
		EventBus.analysis_cleanup_started.emit("object")
		var removed_count := cleanup_unused_object_files(cache_path, path)
		EventBus.analysis_cleanup_completed.emit("object", removed_count)


func _on_project_loaded(_path: String) -> void:
	pass  # Project loaded, BookService is ready


func _on_project_unloaded() -> void:
	pass  # Project unloaded


# Override: Process a single task
func _process_task(task: Dictionary):
	var cache_path: String = task["cache_path"]
	var file_path: String = task["file_path"]
	var file_content: String = task["file_content"]

	# Process the task - extract objects and create/update cache files
	var success := await _extract_and_cache_objects(cache_path, file_path, file_content)
	if not success:
		push_warning("[ObjectService] Failed to process file: %s, but continuing with next task" % file_path)


# Override: Emit queue updated signal
func _emit_queue_updated() -> void:
	EventBus.analysis_queue_updated.emit("object", task_queue.size(), processing)


# Override: Emit task started signal
func _emit_task_started(remaining: int) -> void:
	EventBus.analysis_task_started.emit("object", remaining)


# Override: Emit task completed signal
func _emit_task_completed(remaining: int) -> void:
	EventBus.analysis_task_completed.emit("object", remaining, {})


# Handle file scanned event - queue objects for caching
func queue_objects_for_cache(file_path: String, file_content: String = "") -> void:
	# Get the base directory from the file path
	var dir_path := file_path.get_base_dir()
	var cache_path := dir_path.path_join(".snorfeld").path_join(OBJECT_DIR_NAME)

	# Ensure cache exists for this directory
	if not DirAccess.dir_exists_absolute(cache_path):
		_create_cache_directory(cache_path)

	# Extract objects from the file content using LLM
	_queue_task(cache_path, file_path, file_content)
	_emit_queue_updated()

	# Start processing if not already running
	if not processing:
		await _processing_start()


# Queue a task for object extraction and cache creation
func _queue_task(cache_path: String, file_path: String, file_content: String, priority: bool = false) -> void:
	queue_mutex.lock()
	var task: Dictionary = {"cache_path": cache_path, "file_path": file_path, "file_content": file_content}
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
	await _processing_start()


func _on_priority_object_cache_requested(file_path: String, file_content: String) -> void:
	var dir_path := file_path.get_base_dir()
	var cache_path := dir_path.path_join(".snorfeld").path_join(OBJECT_DIR_NAME)
	if not DirAccess.dir_exists_absolute(cache_path):
		_create_cache_directory(cache_path)
	_queue_task(cache_path, file_path, file_content, true)


func _on_start_analysis(service_type: String, scope: String) -> void:
	if service_type != "OBJECT":
		return
	if scope == "project":
		_on_run_all_object_analyses()
	elif scope == "chapter":
		_on_run_chapter_object_analyses()

func _on_run_all_object_analyses() -> void:
	# Queue all text files from BookService for object analysis
	var all_files := BookService.get_all_files()
	all_files.sort()
	for file_path in all_files:
		var file_data := BookService.get_file(file_path)
		if file_data.is_empty():
			continue
		var content = file_data.get("content", "")
		if content != "":
			queue_objects_for_cache(file_path, content)


func _on_file_selected(path: String) -> void:
	current_object_file_path = path
	if FileAccess.file_exists(path):
		var file := FileAccess.open(path, FileAccess.READ)
		if file:
			current_object_file_content = file.get_as_text()
			file.close()


func _on_run_chapter_object_analyses() -> void:
	if current_object_file_path == "":
		return
	# Get content from BookService if available
	var file_data := BookService.get_file(current_object_file_path)
	if file_data.is_empty():
		if current_object_file_content != "":
			queue_objects_for_cache(current_object_file_path, current_object_file_content)
	else:
		queue_objects_for_cache(current_object_file_path, file_data.get("content", current_object_file_content))


# Extracts objects from file content and creates/updates cache files
func _extract_and_cache_objects(cache_path: String, file_path: String, file_content: String) -> bool:
	# Extract chapter ID from file path (full filename without extension)
	var chapter_id: String = file_path.get_file().get_basename()

	# Load all existing objects from cache to provide context to LLM
	var existing_objects_json: String = _load_existing_objects_json(cache_path)

	# Use LLM to extract/update objects from the chapter text with existing context
	var extraction_result = await _extract_objects_from_text(file_content, chapter_id, existing_objects_json)

	if extraction_result == null or not extraction_result.has("objects"):
		push_error("[ObjectService] Failed to extract objects from file: %s" % file_path)
		return false

	var objects: Array = extraction_result["objects"]
	var success := true

	# Process each object
	for obj_data in objects:
		var obj_name: String = obj_data.get("name", "")
		if obj_name == "":
			continue

		# Check for fuzzy matches with existing object files FIRST
		var existing_file_path: String = _find_matching_object_file(obj_name, cache_path)
		var canonical_name: String = obj_name

		if existing_file_path != "":
			# Use the existing file's canonical name for hashing
			var read_file := FileAccess.open(existing_file_path, FileAccess.READ)
			if read_file:
				var content := read_file.get_as_text()
				read_file.close()
				var json := JSON.new()
				if json.parse(content) == OK:
					var object_data: Dictionary = json.get_data()
					canonical_name = object_data.get("name", obj_name)
					# Also add the new alias to the existing object
					if not object_data.get("aliases", []).has(obj_name):
						var aliases: Array = object_data.get("aliases", [])
						if not aliases.has(obj_name):
							aliases.append(obj_name)
							object_data["aliases"] = aliases

		# Use MD5 hash of the CANONICAL object name for filename
		var obj_hash: String = _hash_object(canonical_name)
		var obj_file_path: String = cache_path.path_join("%s.json" % obj_hash)

		# Load existing data if file exists
		var existing_data: Dictionary = {}
		if _file_exists(obj_file_path):
			var read_file := FileAccess.open(obj_file_path, FileAccess.READ)
			if read_file:
				var content := read_file.get_as_text()
				read_file.close()
				var json := JSON.new()
				if json.parse(content) == OK:
					existing_data = json.get_data()

		# Merge with existing data and add chapter-specific fields
		var updated_data: Dictionary = _merge_object_data(existing_data, obj_data, chapter_id)

		# Save updated object data
		var file := FileAccess.open(obj_file_path, FileAccess.WRITE)
		if file:
			var json_str := JSON.stringify(updated_data)
			file.store_string(json_str)
			file.close()
		else:
			push_error("[ObjectService] Failed to save object file: %s" % obj_file_path)
			success = false

	return success


# Load all existing objects as JSON string for LLM context
func _load_existing_objects_json(cache_path: String) -> String:
	var existing_objs: Array = []
	var dir := DirAccess.open(cache_path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".json"):
				var obj_file_path := cache_path.path_join(file_name)
				var file := FileAccess.open(obj_file_path, FileAccess.READ)
				if file:
					var content := file.get_as_text()
					file.close()
					var json := JSON.new()
					if json.parse(content) == OK:
						var obj_data: Dictionary = json.get_data()
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
			file_name = dir.get_next()
			dir.list_dir_end()

	if existing_objs.size() > 0:
		return JSON.stringify(existing_objs)
	return "[]"


# Merge arrays without duplicates
func _merge_arrays(existing: Array, new: Array) -> Array:
	var merged := []
	var seen: Dictionary = {}
	for item in existing:
		if not seen.has(item):
			merged.append(item)
			seen[item] = true
	for item in new:
		if not seen.has(item):
			merged.append(item)
			seen[item] = true
	return merged


# Merge character relations dictionaries
func _merge_character_relations(existing: Dictionary, new: Dictionary) -> Dictionary:
	var merged := existing.duplicate()
	for key in new:
		merged[key] = new[key]
	return merged


# Merge object data from LLM with existing data, adding chapter-specific fields
func _merge_object_data(existing_data: Dictionary, new_obj_data: Dictionary, chapter_id: String) -> Dictionary:
	var updated_data: Dictionary = {}

	# Start with existing data
	if existing_data.size() > 0:
		updated_data = existing_data.duplicate()

	# Overwrite/merge fields from new data
	# Name - use new if provided, otherwise keep existing
	if new_obj_data.has("name"):
		updated_data["name"] = new_obj_data["name"]

	# Merge object_type
	updated_data["object_type"] = _merge_arrays(existing_data.get("object_type", []), new_obj_data.get("object_type", []))

	# Merge description - concatenate if both exist
	var existing_desc = existing_data.get("description", "")
	var new_desc = new_obj_data.get("description", "")
	if existing_desc != "" and new_desc != "":
		updated_data["description"] = existing_desc + " " + new_desc
	elif new_desc != "":
		updated_data["description"] = new_desc

	# Merge thematic_relevance
	updated_data["thematic_relevance"] = _merge_arrays(existing_data.get("thematic_relevance", []), new_obj_data.get("thematic_relevance", []))

	# Merge character_relations
	updated_data["character_relations"] = _merge_character_relations(existing_data.get("character_relations", {}), new_obj_data.get("character_relations", {}))

	# Merge aliases - filter out any that match the canonical name
	var merged_aliases = _merge_arrays(existing_data.get("aliases", []), new_obj_data.get("aliases", []))
	var canonical_name = updated_data.get("name", "")
	var filtered_aliases = []
	for alias in merged_aliases:
		if alias != canonical_name:
			filtered_aliases.append(alias)
	updated_data["aliases"] = filtered_aliases

	# Add/update appearances - this chapter is always added
	var existing_appearances: Array = existing_data.get("appearances", [])
	if not existing_appearances.has(chapter_id):
		existing_appearances.append(chapter_id)
	updated_data["appearances"] = existing_appearances

	# Add/update notes - chapter-specific notes
	var existing_notes: Dictionary = existing_data.get("notes", {})
	var new_notes = new_obj_data.get("notes", "")
	# Handle both String and Dictionary notes from LLM
	if new_notes is Dictionary:
		# If LLM returned a dict, merge it
		for key in new_notes:
			existing_notes[key] = new_notes[key]
	elif new_notes is String and new_notes != "":
		# If LLM returned a string, use it for this chapter
		existing_notes[chapter_id] = new_notes
	updated_data["notes"] = existing_notes

	# Merge symbolic_meaning
	updated_data["symbolic_meaning"] = _merge_arrays(existing_data.get("symbolic_meaning", []), new_obj_data.get("symbolic_meaning", []))

	return updated_data


# Extract objects from text using LLM
func _extract_objects_from_text(text: String, chapter_id: String, existing_objects_json: String) -> Dictionary:
	var prompt := """
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

	var options := {
		"temperature": AppConfig.get_llm_temperature(),
		"max_tokens": AppConfig.get_llm_max_tokens()
	}

	var llm_response = await LLMClient.generate_json(AppConfig.get_llm_model(), prompt, options)

	if llm_response.get("parsed_json", null) != null:
		return llm_response["parsed_json"]
	else:
		# Retry up to 3 times on failure
		var max_retries := 3
		for _i in range(max_retries):
			# Check if we hit token limit - increase tokens for retry
			if llm_response.get("done", false) == false:
				options["max_tokens"] = options.get("max_tokens", AppConfig.get_llm_max_tokens()) * 2
			llm_response = await LLMClient.generate_json(AppConfig.get_llm_model(), prompt, options)
			if llm_response.get("parsed_json", null) != null:
				return llm_response["parsed_json"]

		push_error("[ObjectService] Failed to parse object extraction response after %d retries" % max_retries)
		return {"objects": []}


# Find matching object file using fuzzy matching
func _find_matching_object_file(obj_name: String, cache_path: String) -> String:
	var dir := DirAccess.open(cache_path)
	if not dir:
		return ""

	var best_match: String = ""
	var best_score := 0

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			var file_path := cache_path.path_join(file_name)
			var file := FileAccess.open(file_path, FileAccess.READ)
			if file:
				var content := file.get_as_text()
				file.close()
				var json := JSON.new()
				if json.parse(content) == OK:
					var data: Dictionary = json.get_data()
					var existing_name: String = data.get("name", "")

					# Compare against the actual object name
					var score := _calculate_similarity(obj_name, existing_name)
					if score > best_score:
						best_score = score
						best_match = file_path

					# Also check aliases
					var aliases: Array = data.get("aliases", [])
					for alias in aliases:
						var alias_score := _calculate_similarity(obj_name, alias)
						if alias_score > best_score:
							best_score = alias_score
							best_match = file_path
						if alias_score > 80:
							break
					if best_score > 80:
						break
			file_name = dir.get_next()
	dir.list_dir_end()

	# Return match if score is above threshold
	if best_score > 80:
		return best_match
	return ""


# Calculate similarity between two strings (same as CharacterService)
func _calculate_similarity(str1: String, str2: String) -> int:
	var s1 := str1.to_lower()
	var s2 := str2.to_lower()

	if s1 == s2:
		return 100

	if s1.find(s2) != -1 or s2.find(s1) != -1:
		return 90

	var words1 := s1.split(" ", false)
	var words2 := s2.split(" ", false)
	var common_count := 0

	for word1 in words1:
		for word2 in words2:
			if word1 == word2 and word1.length() > 2:
				common_count += 1
				break

	var total_words := words1.size() + words2.size()
	if total_words == 0:
		return 0

	return int((common_count * 2.0 / total_words) * 100)


# Creates an MD5 hash from an object name string
func _hash_object(object_name: String) -> String:
	var hash_ctx := HashingContext.new()
	hash_ctx.start(HashingContext.HASH_MD5)
	hash_ctx.update(object_name.to_utf8_buffer())
	var hash_bytes := hash_ctx.finish()
	return hash_bytes.hex_encode()


# Check if file exists
func _file_exists(path: String) -> bool:
	return FileUtils.file_exists(path)


# Get the object cache path for the current project
func get_cache_path() -> String:
	var project_path := BookService.loaded_project_path
	if project_path == "":
		project_path = "res://"
	var cache_path := project_path.path_join(".snorfeld").path_join(OBJECT_DIR_NAME)
	return cache_path


# Get all object files in the cache directory
func get_all_objects(cache_path: String) -> Array:
	var objects: Array = []
	var dir := DirAccess.open(cache_path)
	if not dir:
		return objects

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			var file_path := cache_path.path_join(file_name)
			var file := FileAccess.open(file_path, FileAccess.READ)
			if file:
				var content := file.get_as_text()
				file.close()
				var json := JSON.new()
				if json.parse(content) == OK:
					objects.append(json.get_data())
		file_name = dir.get_next()
	dir.list_dir_end()

	return objects


# Get all objects for the current project
func get_all_project_objects() -> Array:
	var cache_path := get_cache_path()
	return get_all_objects(cache_path)


# Get a specific object by name
func get_object(obj_name: String, cache_path: String) -> Dictionary:
	# Use MD5 hash of object name for filename
	var obj_hash: String = _hash_object(obj_name)
	var obj_file_path: String = cache_path.path_join("%s.json" % obj_hash)

	# First try exact hash match
	if _file_exists(obj_file_path):
		var file := FileAccess.open(obj_file_path, FileAccess.READ)
		if file:
			var content := file.get_as_text()
			file.close()
			var json := JSON.new()
			if json.parse(content) == OK:
				return json.get_data()

	# Try fuzzy match
	var matched_path: String = _find_matching_object_file(obj_name, cache_path)
	if matched_path != "":
		var file := FileAccess.open(matched_path, FileAccess.READ)
		if file:
			var content := file.get_as_text()
			file.close()
			var json := JSON.new()
			if json.parse(content) == OK:
				return json.get_data()

	return {}


# Clean up object cache files that don't have corresponding source files in the project
func cleanup_unused_object_files(cache_path: String, project_path: String) -> int:
	var dir := DirAccess.open(cache_path)
	if not dir:
		return 0

	var removed_count := 0
	var project_files: Array = FileUtils.get_all_text_files(project_path)

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			var cache_file_path := cache_path.path_join(file_name)
			var file := FileAccess.open(cache_file_path, FileAccess.READ)
			if file:
				var cache_content := file.get_as_text()
				file.close()
				var json := JSON.new()
				if json.parse(cache_content) == OK:
					var data: Dictionary = json.get_data()
					var appearances: Array = data.get("appearances", [])
					var all_missing := true

					# Check if any appearance references a file that still exists
					for appearance in appearances:
						for project_file in project_files:
							if project_file.get_file().get_basename() == appearance:
								all_missing = false
								break
						if not all_missing:
							break

					if all_missing:
						if DirAccess.remove_absolute(cache_file_path) == OK:
							removed_count += 1
						else:
							push_error("Failed to delete object cache file: %s" % cache_file_path)
				else:
					push_warning("Failed to parse object cache file: %s - removing" % file_name)
					if DirAccess.remove_absolute(cache_file_path) == OK:
						removed_count += 1
					else:
						push_error("Failed to delete corrupt object cache file: %s" % cache_file_path)
			else:
				push_error("Failed to open object cache file: %s" % file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

	return removed_count
