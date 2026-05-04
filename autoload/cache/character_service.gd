extends ContentCache
# Character service - handles caching and analysis of character results

const CHARACTER_DIR_NAME := "characters"

# Track the current file for character analysis
var current_character_file_path: String = ""
var current_character_file_content: String = ""

func _ready() -> void:
	EventBus.request_priority_character_cache.connect(_on_priority_character_cache_requested)
	EventBus.run_all_character_analyses.connect(_on_run_all_character_analyses)
	EventBus.run_chapter_character_analyses.connect(_on_run_chapter_character_analyses)
	EventBus.file_selected.connect(_on_file_selected)
	EventBus.folder_opened.connect(_on_folder_opened)


# Override: Get cache subdirectory name
func _get_cache_subdir() -> String:
	return CHARACTER_DIR_NAME

func _on_folder_opened(path: String) -> void:
	var cache_path := path.path_join(".snorfeld").path_join(CHARACTER_DIR_NAME)
	if DirAccess.dir_exists_absolute(cache_path):
		EventBus.cache_cleanup_started.emit()
		var removed_count := cleanup_unused_character_files(cache_path, path)
		EventBus.cache_cleanup_completed.emit(removed_count)


# Override: Process a single task
func _process_task(task: Dictionary):
	var cache_path: String = task["cache_path"]
	var file_path: String = task["file_path"]
	var file_content: String = task["file_content"]

	# Process the task - extract characters and create/update cache files
	await _extract_and_cache_characters(cache_path, file_path, file_content)


# Override: Emit queue updated signal
func _emit_queue_updated() -> void:
	EventBus.character_cache_queue_updated.emit(task_queue.size(), processing)


# Override: Emit task started signal
func _emit_task_started(remaining: int) -> void:
	EventBus.character_cache_task_started.emit(remaining)


# Override: Emit task completed signal
func _emit_task_completed(remaining: int) -> void:
	EventBus.character_cache_task_completed.emit(remaining)


# Handle file scanned event - queue characters for caching
func queue_characters_for_cache(file_path: String, file_content: String = "") -> void:
	# Get the base directory from the file path
	var dir_path := file_path.get_base_dir()
	var cache_path := dir_path.path_join(".snorfeld").path_join(CHARACTER_DIR_NAME)

	# Ensure cache exists for this directory
	if not DirAccess.dir_exists_absolute(cache_path):
		_create_cache_directory(cache_path)

	# Extract characters from the file content using LLM
	_queue_task(cache_path, file_path, file_content)
	_emit_queue_updated()

	# Start processing if not already running
	if not processing:
		_processing_start()


# Queue a task for character extraction and cache creation
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
	_processing_start()


func _on_priority_character_cache_requested(file_path: String, file_content: String) -> void:
	var dir_path := file_path.get_base_dir()
	var cache_path := dir_path.path_join(".snorfeld").path_join(CHARACTER_DIR_NAME)
	if not DirAccess.dir_exists_absolute(cache_path):
		_create_cache_directory(cache_path)
	_queue_task(cache_path, file_path, file_content, true)


func _on_run_all_character_analyses() -> void:
	# Queue all text files in the project for character analysis
	var project_path := ProjectState.get_current_path()
	if project_path == "":
		return
	var text_files: Array = FileUtils.get_all_text_files(project_path)
	# Sort files alphabetically to process in order
	text_files.sort()
	for file_path in text_files:
		var file := FileAccess.open(file_path, FileAccess.READ)
		if file:
			var content := file.get_as_text()
			file.close()
			queue_characters_for_cache(file_path, content)


func _on_file_selected(path: String) -> void:
	current_character_file_path = path
	if FileAccess.file_exists(path):
		var file := FileAccess.open(path, FileAccess.READ)
		if file:
			current_character_file_content = file.get_as_text()
			file.close()


func _on_run_chapter_character_analyses() -> void:
	if current_character_file_path == "":
		return
	queue_characters_for_cache(current_character_file_path, current_character_file_content)


# Extracts characters from file content and creates/updates cache files
func _extract_and_cache_characters(cache_path: String, file_path: String, file_content: String) -> bool:
	# Extract chapter ID from file path (full filename without extension)
	var chapter_id: String = file_path.get_file().get_basename()

	# Load all existing characters from cache to provide context to LLM
	var existing_characters_json: String = _load_existing_characters_json(cache_path)

	# Use LLM to extract/update characters from the chapter text with existing context
	var extraction_result = await _extract_characters_from_text(file_content, chapter_id, existing_characters_json)

	if extraction_result == null or not extraction_result.has("characters"):
		print("[CharacterService] Failed to extract characters from file: %s" % file_path)
		return false

	var characters: Array = extraction_result["characters"]
	var success := true

	# Process each character
	for char_data in characters:
		var char_name: String = char_data.get("name", "")
		if char_name == "":
			continue

		# Check for fuzzy matches with existing character files FIRST
		# This handles cases where LLM returns "Alex (past)" but we already have "Alex"
		var existing_file_path: String = _find_matching_character_file(char_name, cache_path)
		var canonical_name: String = char_name

		if existing_file_path != "":
			# Use the existing file's canonical name for hashing
			var read_file := FileAccess.open(existing_file_path, FileAccess.READ)
			if read_file:
				var content := read_file.get_as_text()
				read_file.close()
				var json := JSON.new()
				if json.parse(content) == OK:
					var character_data: Dictionary = json.get_data()
					canonical_name = character_data.get("name", char_name)
					# Also add the new alias to the existing character
					if not character_data.get("aliases", []).has(char_name):
						var aliases: Array = character_data.get("aliases", [])
						if not aliases.has(char_name):
							aliases.append(char_name)
							character_data["aliases"] = aliases

		# Use MD5 hash of the CANONICAL character name for filename
		var char_hash: String = _hash_character(canonical_name)
		var char_file_path: String = cache_path.path_join("%s.json" % char_hash)

		# Load existing data if file exists
		var existing_data: Dictionary = {}
		if _file_exists(char_file_path):
			var read_file := FileAccess.open(char_file_path, FileAccess.READ)
			if read_file:
				var content := read_file.get_as_text()
				read_file.close()
				var json := JSON.new()
				if json.parse(content) == OK:
					existing_data = json.get_data()

		# Merge with existing data and add chapter-specific fields
		var updated_data: Dictionary = _merge_character_data(existing_data, char_data, chapter_id)

		# Save updated character data
		var file := FileAccess.open(char_file_path, FileAccess.WRITE)
		if file:
			var json_str := JSON.stringify(updated_data)
			file.store_string(json_str)
			file.close()
		else:
			push_error("[CharacterService] Failed to save character file: %s" % char_file_path)
			success = false

	return success


# Load all existing characters as JSON string for LLM context
func _load_existing_characters_json(cache_path: String) -> String:
	var existing_chars: Array = []
	var dir := DirAccess.open(cache_path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".json"):
				var char_file_path := cache_path.path_join(file_name)
				var file := FileAccess.open(char_file_path, FileAccess.READ)
				if file:
					var content := file.get_as_text()
					file.close()
					var json := JSON.new()
					if json.parse(content) == OK:
						var char_data: Dictionary = json.get_data()
						# Create a clean version without bookkeeping fields
						var clean_char: Dictionary = {}
						clean_char["name"] = char_data.get("name", "")
						if char_data.has("plot_roles"):
							clean_char["plot_roles"] = char_data["plot_roles"]
						if char_data.has("archetypes"):
							clean_char["archetypes"] = char_data["archetypes"]
						if char_data.has("traits"):
							clean_char["traits"] = char_data["traits"]
						if char_data.has("relationships"):
							clean_char["relationships"] = char_data["relationships"]
						if char_data.has("aliases"):
							clean_char["aliases"] = char_data["aliases"]
						existing_chars.append(clean_char)
			file_name = dir.get_next()
			dir.list_dir_end()

	if existing_chars.size() > 0:
		return JSON.stringify(existing_chars)
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


# Merge relationships dictionaries
func _merge_relationships(existing: Dictionary, new: Dictionary) -> Dictionary:
	var merged := existing.duplicate()
	for key in new:
		merged[key] = new[key]
	return merged


# Merge character data from LLM with existing data, adding chapter-specific fields
func _merge_character_data(existing_data: Dictionary, new_char_data: Dictionary, chapter_id: String) -> Dictionary:
	var updated_data: Dictionary = {}

	# Start with existing data
	if existing_data.size() > 0:
		updated_data = existing_data.duplicate()

	# Overwrite/merge fields from new data
	# Name - use new if provided, otherwise keep existing
	if new_char_data.has("name"):
		updated_data["name"] = new_char_data["name"]

	# Merge plot_roles
	updated_data["plot_roles"] = _merge_arrays(existing_data.get("plot_roles", []), new_char_data.get("plot_roles", []))

	# Merge archetypes
	updated_data["archetypes"] = _merge_arrays(existing_data.get("archetypes", []), new_char_data.get("archetypes", []))

	# Merge traits
	updated_data["traits"] = _merge_arrays(existing_data.get("traits", []), new_char_data.get("traits", []))

	# Merge relationships
	updated_data["relationships"] = _merge_relationships(existing_data.get("relationships", {}), new_char_data.get("relationships", {}))

	# Merge aliases - filter out any that match the canonical name
	var merged_aliases = _merge_arrays(existing_data.get("aliases", []), new_char_data.get("aliases", []))
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
	var new_notes = new_char_data.get("notes", "")
	# Handle both String and Dictionary notes from LLM
	if new_notes is Dictionary:
		# If LLM returned a dict, merge it
		for key in new_notes:
			existing_notes[key] = new_notes[key]
	elif new_notes is String and new_notes != "":
		# If LLM returned a string, use it for this chapter
		existing_notes[chapter_id] = new_notes
	updated_data["notes"] = existing_notes

	return updated_data


# Extract characters from text using LLM
func _extract_characters_from_text(text: String, chapter_id: String, existing_characters_json: String) -> Dictionary:
	var prompt := """
You are a helpful writing assistant specializing in character analysis for a novel. Analyze the following chapter text.

Your task is to identify the characters that appear in this chapter and provide their complete, consistent profiles. Use the existing character database to maintain consistency.

IMPORTANT GUIDELINES:
- Be CONSISTENT: Use the EXACT same character names from existing characters when they reappear
- Be COMPACT: Use concise, standardized traits, archetypes, and roles - avoid synonyms and duplicates
- Be SELECTIVE: Focus on actual named characters, ignore background figures, mentions of people, and generic descriptions of characters
- Be COMPLETE: Include all relevant information revealed in this chapter

Existing characters for reference:
%s

Chapter: %s

Chapter Text:
%s

For each character that appears in this chapter, return their complete profile:
- name: EXACT match with existing characters if they exist
- plot_roles: Array of their role(s) in the story
- archetypes: Array of their character archetype(s) - use consistent, standard terms
- traits: Array of their personality traits - use consistent, standard terms, no duplicates
- relationships: Object of {character_name: relationship_description}
- aliases: Array of OTHER NAMES they are LITERALLY called in this chapter text (only if the exact alias string appears as a name in the chapter)
- notes: Brief description of their appearance/role in THIS chapter

IMPORTANT: Only include an alias if that exact string is used as a name for the character in this chapter. Do NOT include descriptive phrases, roles, pronouns, or empty strings as aliases.

Respond with a JSON object:
{
  "characters": [
    {
      "name": "Character Name",
      "plot_roles": ["protagonist"],
      "archetypes": ["hero"],
      "traits": ["brave", "determined"],
      "relationships": {"OtherChar": "friend"},
      "aliases": ["Nickname"],
      "notes": "What they do in this chapter"
    }
  ]
}
""" % [existing_characters_json, chapter_id, text]

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
		for retry in range(max_retries):
			# Check if we hit token limit - increase tokens for retry
			if llm_response.get("done", false) == false:
				options["max_tokens"] = options.get("max_tokens", AppConfig.get_llm_max_tokens()) * 2
				print("[CharacterService] Token limit reached, retrying %d/%d with max_tokens: %d" % [retry + 1, max_retries, options["max_tokens"]])
			else:
				print("[CharacterService] Parse failed, retrying %d/%d" % [retry + 1, max_retries])

			llm_response = await LLMClient.generate_json(AppConfig.get_llm_model(), prompt, options)
			if llm_response.get("parsed_json", null) != null:
				return llm_response["parsed_json"]

		push_error("[CharacterService] Failed to parse character extraction response after %d retries" % max_retries)
		print(llm_response)
		return {"characters": []}


# Find matching character file using fuzzy matching
func _find_matching_character_file(char_name: String, cache_path: String) -> String:
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

					# Compare against the actual character name
					var score := _calculate_similarity(char_name, existing_name)
					if score > best_score:
						best_score = score
						best_match = file_path

					# Also check aliases
					var aliases: Array = data.get("aliases", [])
					for alias in aliases:
						var alias_score := _calculate_similarity(char_name, alias)
						if alias_score > best_score:
							best_score = alias_score
							best_match = file_path
						if alias_score > 80:
							break
					if best_score > 80:
						break
				if best_score > 80:
					break
		file_name = dir.get_next()
	dir.list_dir_end()

	# Return match if score is above threshold
	if best_score > 80:
		return best_match
	return ""


# Calculate similarity between two strings
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


# Creates an MD5 hash from a character name string
func _hash_character(character_name: String) -> String:
	var hash_ctx := HashingContext.new()
	hash_ctx.start(HashingContext.HASH_MD5)
	hash_ctx.update(character_name.to_utf8_buffer())
	var hash_bytes := hash_ctx.finish()
	return hash_bytes.hex_encode()


# Check if file exists
func _file_exists(path: String) -> bool:
	return FileUtils.file_exists(path)


# Get the character cache path for the current project
func get_cache_path() -> String:
	var project_path := ProjectState.get_current_path()
	if project_path == "":
		project_path = "res://"
	var cache_path := project_path.path_join(".snorfeld").path_join(CHARACTER_DIR_NAME)
	return cache_path


# Get all character files in the cache directory
func get_all_characters(cache_path: String) -> Array:
	var characters: Array = []
	var dir := DirAccess.open(cache_path)
	if not dir:
		return characters

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
					characters.append(json.get_data())
		file_name = dir.get_next()
	dir.list_dir_end()

	return characters


# Get all characters for the current project
func get_all_project_characters() -> Array:
	var cache_path := get_cache_path()
	return get_all_characters(cache_path)


# Get a specific character by name
func get_character(char_name: String, cache_path: String) -> Dictionary:
	# Use MD5 hash of character name for filename
	var char_hash: String = _hash_character(char_name)
	var char_file_path: String = cache_path.path_join("%s.json" % char_hash)

	# First try exact hash match
	if _file_exists(char_file_path):
		var file := FileAccess.open(char_file_path, FileAccess.READ)
		if file:
			var content := file.get_as_text()
			file.close()
			var json := JSON.new()
			if json.parse(content) == OK:
				return json.get_data()

	# Try fuzzy match
	var matched_path: String = _find_matching_character_file(char_name, cache_path)
	if matched_path != "":
		var file := FileAccess.open(matched_path, FileAccess.READ)
		if file:
			var content := file.get_as_text()
			file.close()
			var json := JSON.new()
			if json.parse(content) == OK:
				return json.get_data()

	return {}


# Clean up character cache files that don't have corresponding source files in the project
func cleanup_unused_character_files(cache_path: String, project_path: String) -> int:
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
							push_error("Failed to delete character cache file: %s" % cache_file_path)
				else:
					push_warning("Failed to parse character cache file: %s - removing" % file_name)
					if DirAccess.remove_absolute(cache_file_path) == OK:
						removed_count += 1
					else:
						push_error("Failed to delete corrupt character cache file: %s" % cache_file_path)
			else:
				push_error("Failed to open character cache file: %s" % file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

	return removed_count
