extends AnalysisService
# Character service - handles caching and analysis of character results

# gdlint:ignore-file:file-length,deep-nesting,long-function,magic-number,long-line,high-complexity

const CHARACTER_DIR_NAME := "characters"

func _ready() -> void:
	# Configure service properties
	service_name = "character"
	cache_subdir = CHARACTER_DIR_NAME
	cache_filename = "characters.jsonl"

	# Enable merging - same character can appear in multiple chapters
	should_merge_on_duplicate = true

	# Configure merge strategies for character fields
	merge_strategies = {
		"name": MergeUtils.MergeStrategy.REPLACE,
		"plot_roles": MergeUtils.MergeStrategy.ARRAY_MERGE_UNIQUE,
		"archetypes": MergeUtils.MergeStrategy.ARRAY_MERGE_UNIQUE,
		"traits": MergeUtils.MergeStrategy.ARRAY_MERGE_UNIQUE,
		"relationships": MergeUtils.MergeStrategy.DICT_MERGE,
		"aliases": MergeUtils.MergeStrategy.ARRAY_MERGE_UNIQUE,
		"appearances": MergeUtils.MergeStrategy.ARRAY_APPEND,
		"notes": MergeUtils.MergeStrategy.DICT_MERGE,
		"symbolic_meaning": MergeUtils.MergeStrategy.ARRAY_MERGE_UNIQUE,
		"object_type": MergeUtils.MergeStrategy.ARRAY_MERGE_UNIQUE,
		"description": MergeUtils.MergeStrategy.CONCAT,
		"thematic_relevance": MergeUtils.MergeStrategy.ARRAY_MERGE_UNIQUE,
		"character_relations": MergeUtils.MergeStrategy.DICT_MERGE,
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
# For characters, the key is the MD5 hash of the canonical character name
# For file-level payloads, use file path hash
func _get_cache_key(payload: Dictionary) -> String:
	# File-level analysis (from queue_characters_for_cache)
	if payload.has("file_path"):
		return HashingUtils.hash_md5(payload["file_path"])
	# Character-level analysis
	var char_name: String = payload.get("name", "")
	if char_name != "":
		return _hash_character(char_name)
	return payload.get("hash", "")


# Override: Get cache key from loaded data
func _get_cache_key_from_data(data: Dictionary) -> String:
	if data.has("name"):
		return _hash_character(data["name"])
	return ""

# Get the cache directory for a file path
func _get_cache_dir_for_file(file_path: String) -> String:
	return file_path.get_base_dir().path_join(".snorfeld").path_join(CHARACTER_DIR_NAME)

# Creates an MD5 hash from a character name string
func _hash_character(character_name: String) -> String:
	return HashingUtils.hash_md5(character_name)


## ============================================================================
## Analysis
## ============================================================================

# Override: Analyze a file and extract characters
func _analyze(payload: Dictionary) -> Dictionary:
	var cache_path: String = payload.get("cache_path", "")
	var file_path: String = payload.get("file_path", "")
	var file_content: String = payload.get("file_content", "")

	# Process the task - extract characters and return cache data
	return await _extract_and_cache_characters(cache_path, file_path, file_content)


## ============================================================================
## Task Processing Overrides
## ============================================================================

# Override: Process a single task - delegates to _analyze
func _process_task(task: Dictionary) -> void:
	var result := await _analyze(task)
	if result != null and not result.is_empty():
		# Store the result - AnalysisService will handle caching
		# The _analyze method returns data that should be cached
		# But for characters, _extract_and_cache_characters already handles saving
		pass


# Override: Emit queue updated signal
func _emit_queue_updated() -> void:
	EventBus.analysis_queue_updated.emit("character", task_queue.size())


# Override: Emit task started signal
func _emit_task_started(remaining: int) -> void:
	EventBus.analysis_task_started.emit("character", remaining)


# Override: Emit task completed signal
func _emit_task_completed(remaining: int) -> void:
	EventBus.analysis_task_completed.emit("character", remaining)


## ============================================================================
## Queue Management
## ============================================================================

# Handle file scanned event - queue characters for caching
func queue_characters_for_cache(file_path: String, file_content: String = "") -> void:
	# Get the base directory from the file path
	var cache_path: String = _get_cache_dir_for_file(file_path)

	# Ensure cache directory exists
	if not FileUtils.dir_exists(cache_path):
		_create_cache_directory(cache_path)

	# Check if already cached or queued (using file path as key for deduplication)
	var file_path_hash: String = HashingUtils.hash_md5(file_path)
	if is_cached(file_path_hash) and not should_merge_on_duplicate:
		return

	# Queue task
	var payload: Dictionary = {"cache_path": cache_path, "file_path": file_path, "file_content": file_content}
	queue_task(payload, false)


# Queue a task for character extraction and cache creation
func _queue_task(cache_path: String, file_path: String, file_content: String, priority: bool = false) -> void:
	var payload: Dictionary = {"cache_path": cache_path, "file_path": file_path, "file_content": file_content}
	queue_task(payload, priority)


func _on_priority_character_cache_requested(file_path: String, file_content: String) -> void:
	var cache_path: String = _get_cache_dir_for_file(file_path)
	if not FileUtils.dir_exists(cache_path):
		_create_cache_directory(cache_path)
	_queue_task(cache_path, file_path, file_content, true)


## ============================================================================
## Signal Handlers
## ============================================================================

func _on_folder_opened(path: String) -> void:
	var cache_path: String = path.path_join(".snorfeld").path_join(CHARACTER_DIR_NAME)
	if DirAccess.dir_exists_absolute(cache_path):
		_ensure_cache_loaded(cache_path)
		EventBus.analysis_cleanup_started.emit("character")
		var removed_count: int = _cleanup_unused_cache_files(cache_path, path)
		EventBus.analysis_cleanup_completed.emit("character", removed_count)


func _on_project_loaded(_path: String) -> void:
	pass  # Project loaded, BookService is ready


func _on_project_unloaded() -> void:
	pass  # Project unloaded


func _on_start_analysis(service_type: String, scope: String) -> void:
	if service_type != "CHARACTER":
		return
	if scope == "project":
		_on_run_all_character_analyses()
	elif scope == "chapter":
		_on_run_chapter_character_analyses()


func _on_run_all_character_analyses() -> void:
	# Queue all text files from BookService for character analysis
	var all_files: Array = BookService.get_all_files()
	all_files.sort()
	for file_path in all_files:
		var file_data: Dictionary = BookService.get_file(file_path)
		if file_data.is_empty():
			continue
		var content: String = file_data.get("content", "")
		if content != "":
			queue_characters_for_cache(file_path, content)


func _on_file_selected(path: String) -> void:
	current_file_path = path
	if FileAccess.file_exists(path):
		var file: FileAccess = FileAccess.open(path, FileAccess.READ)
		if file:
			current_file_content = file.get_as_text()
			file.close()


func _on_run_chapter_character_analyses() -> void:
	if current_file_path == "":
		return
	# Get content from BookService if available
	var file_data: Dictionary = BookService.get_file(current_file_path)
	if file_data.is_empty():
		if current_file_content != "":
			queue_characters_for_cache(current_file_path, current_file_content)
	else:
		queue_characters_for_cache(current_file_path, file_data.get("content", current_file_content))


## ============================================================================
## Character Extraction and Caching
## ============================================================================

# Extracts characters from file content and creates/updates cache files
func _extract_and_cache_characters(cache_path: String, file_path: String, file_content: String) -> Dictionary:
	# Extract chapter ID from file path (full filename without extension)
	var chapter_id: String = file_path.get_file().get_basename()

	# Load all existing characters from memory cache for context
	_ensure_cache_loaded(cache_path)
	var existing_characters_json: String = _load_existing_characters_json(cache_path)

	# Use LLM to extract/update characters from the chapter text with existing context
	var extraction_result: Dictionary = await _extract_characters_from_text(file_content, chapter_id, existing_characters_json)

	if extraction_result == null or not extraction_result.has("characters"):
		push_error("[CharacterService] Failed to extract characters from file: %s" % file_path)
		return {}

	var characters: Array = extraction_result["characters"]

	# Process each character
	for char_data in characters:
		var char_name: String = char_data.get("name", "")
		if char_name == "":
			continue

		# Check for fuzzy matches with existing characters in memory cache FIRST
		var canonical_name: String = char_name
		var char_hash: String = _hash_character(char_name)

		# Check if we already have this character in memory
		if memory_cache.has(char_hash):
			var existing_char_data: Dictionary = memory_cache[char_hash]
			canonical_name = existing_char_data.get("name", char_name)
			char_hash = _hash_character(canonical_name)
			# Add alias if not present
			if not existing_char_data.get("aliases", []).has(char_name):
				var aliases: Array = existing_char_data.get("aliases", []).duplicate()
				if not aliases.has(char_name):
					aliases.append(char_name)
					char_data["aliases"] = aliases

		# Load existing data from memory cache
		var existing_data: Dictionary = memory_cache.get(char_hash, {})

		# Merge with existing data and add chapter-specific fields
		var updated_data: Dictionary = _merge_character_data(existing_data, char_data, chapter_id)

		# Store in memory cache
		memory_cache[char_hash] = updated_data

	# Save all to JSONL
	_rewrite_jsonl_file(cache_path)

	return {"success": true, "character_count": characters.size()}


# Load all existing characters as JSON string for LLM context
func _load_existing_characters_json(_cache_path: String) -> String:
	var existing_chars: Array = []
	for key in memory_cache:
		var char_data: Dictionary = memory_cache[key]
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

	if existing_chars.size() > 0:
		return JSON.stringify(existing_chars)
	return "[]"


## ============================================================================
## Merge Logic
## ============================================================================

# Merge arrays without duplicates
func _merge_arrays(existing: Array, new: Array) -> Array:
	return MergeUtils.merge_arrays_unique(existing, new)


# Merge relationships dictionaries
func _merge_relationships(existing: Dictionary, new: Dictionary) -> Dictionary:
	return MergeUtils.merge_dictionaries(existing, new)


# Merge character data from LLM with existing data, adding chapter-specific fields
func _merge_character_data(existing_data: Dictionary, new_char_data: Dictionary, chapter_id: String) -> Dictionary:
	# Turn notes field of new_char into a dictionry
	if new_char_data.has("notes"):
		new_char_data["notes"] = {chapter_id: new_char_data["notes"]}

	# Use the merge strategies configured in the service
	var merged: Dictionary = MergeUtils.merge_data_with_strategies(existing_data, new_char_data, merge_strategies)

	# Special handling for appearances - always add this chapter
	var existing_appearances: Array = merged.get("appearances", [])
	if not existing_appearances.has(chapter_id):
		existing_appearances.append(chapter_id)
		merged["appearances"] = existing_appearances

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

# Extract characters from text using LLM
func _extract_characters_from_text(text: String, chapter_id: String, existing_characters_json: String) -> Dictionary:
	var prompt: String = _build_character_extraction_prompt(existing_characters_json, chapter_id, text)
	var options: Dictionary = _get_llm_options()
	return await _call_llm_with_retry_characters(prompt, options, 3)


## Get LLM options
func _get_llm_options() -> Dictionary:
	return {
		"temperature": AppConfig.get_llm_temperature(),
		"max_tokens": AppConfig.get_llm_max_tokens()
	}


## Build the prompt for character extraction
# gdlint:ignore-function:high-complexity
func _build_character_extraction_prompt(existing_characters_json: String, chapter_id: String, text: String) -> String:
	return """
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


## Call LLM with retry logic for characters
func _call_llm_with_retry_characters(prompt: String, options: Dictionary, max_retries: int) -> Dictionary:
	var llm_response: Dictionary = await LLMClient.generate_json(AppConfig.get_llm_model(), prompt, options)
	if llm_response.get("parsed_json", null) != null:
		return llm_response["parsed_json"]

	for _i in range(max_retries):
		if llm_response.get("done", false) == false:
			options["max_tokens"] = options.get("max_tokens", AppConfig.get_llm_max_tokens()) * 2
		llm_response = await LLMClient.generate_json(AppConfig.get_llm_model(), prompt, options)
		if llm_response.get("parsed_json", null) != null:
			return llm_response["parsed_json"]

	push_error("[CharacterService] Failed to parse character extraction response after %d retries" % max_retries)
	return {"characters": []}


## ============================================================================
## Fuzzy Matching
## ============================================================================

# Find matching character in memory cache using fuzzy matching
# Returns the character hash key if found, empty string otherwise
func _find_matching_character_key(char_name: String) -> String:
	var best_match_key: String = ""
	var best_score: int = 0

	for key in memory_cache:
		var data: Dictionary = memory_cache[key]
		var existing_name: String = data.get("name", "")

		# Check against the actual character name
		var score: int = HashingUtils.calculate_similarity(char_name, existing_name)
		if score > best_score:
			best_score = score
			best_match_key = key

		# Check against aliases
		if data.has("aliases") and data["aliases"] is Array:
			for alias in data["aliases"]:
				var alias_score: int = HashingUtils.calculate_similarity(char_name, alias)
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

# Get the character cache path for the current project
func get_cache_path() -> String:
	var project_path: String = BookService.loaded_project_path
	if project_path == "":
		project_path = "res://"
	return project_path.path_join(".snorfeld").path_join(CHARACTER_DIR_NAME)


# Get all character files in the cache directory
func get_all_characters(cache_path: String) -> Array:
	var characters: Array = []
	_ensure_cache_loaded(cache_path)
	for key in memory_cache:
		characters.append(memory_cache[key])
	return characters


# Get all characters for the current project
func get_all_project_characters() -> Array:
	var cache_path: String = get_cache_path()
	return get_all_characters(cache_path)


# Get a specific character by name
func get_character(char_name: String, cache_path: String) -> Dictionary:
	# Use MD5 hash of character name for key
	var char_hash: String = _hash_character(char_name)
	_ensure_cache_loaded(cache_path)

	# First try exact hash match
	if memory_cache.has(char_hash):
		return memory_cache[char_hash]

	# Try fuzzy match
	var matched_key: String = _find_matching_character_key(char_name)
	if matched_key != "":
		return memory_cache[matched_key]

	return {}


## ============================================================================
## Cleanup
## ============================================================================

# Clean up character cache files that don't have corresponding source files in the project
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
