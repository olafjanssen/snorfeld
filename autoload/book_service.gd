extends Node
## BookService - Central content model for the project
## Maintains a view of all files, chapters, and paragraphs

# Project content structure:
# - files: Dictionary of file_path -> FileData
# - chapters: Dictionary of chapter_id -> ChapterData
# - paragraphs: Dictionary of paragraph_hash -> ParagraphData

const CHAPTER_ID_PREFIX := "ch_"
const PARAGRAPH_ID_PREFIX := "p_"

# Main content store
var files: Dictionary = {}
var chapters: Dictionary = {}
var paragraphs: Dictionary = {}

# Track loaded state
var loaded_project_path: String = ""

# Signals
signal project_loaded(path: String)
signal project_unloaded
signal content_changed

func _ready() -> void:
	EventBus.folder_opened.connect(_on_folder_opened)
	EventBus.file_changed.connect(_on_file_changed)
	EventBus.file_saved.connect(_on_file_saved)


# Load project content from a directory
func load_project(path: String) -> void:
	if path == loaded_project_path:
		return

	# Unload current project
	unload_project()

	if path == "":
		return

	loaded_project_path = path
	_build_content_model(path)
	project_loaded.emit(path)


# Unload current project
func unload_project() -> void:
	files.clear()
	chapters.clear()
	paragraphs.clear()
	loaded_project_path = ""
	project_unloaded.emit()


# Rebuild content model from scratch
func _build_content_model(project_path: String) -> void:
	var text_files := FileUtils.get_all_text_files(project_path)

	for file_path in text_files:
		_add_file(file_path)


# Add or update a file in the model
func _add_file(file_path: String) -> void:
	var content := FileUtils.read_file(file_path)
	if content == "":
		return

	# File hash based on content
	var file_hash := hash_text(content)

	# File data
	var file_data := {
		"path": file_path,
		"hash": file_hash,
		"content": content,
		"chapters": [],
		"paragraphs": [],
		"modified_time": FileUtils.get_modified_time(file_path)
	}
	files[file_path] = file_data

	# Determine chapter level for this file
	var chapter_level := _determine_chapter_level(content)

	# Parse chapters from markdown headings
	var chapter_id_counter := 0
	var current_chapter_id: String = ""

	var lines := content.split("\n")
	var line_num := 0
	var paragraph_start_line := 0
	var current_paragraph_text := ""

	for line in lines:
		line_num += 1
		var stripped := line.strip_edges()

		# Check for chapter heading (dynamic level)
		if stripped.begins_with("#") and stripped.length() > 1:
			var level := 0
			while level < stripped.length() and stripped[level] == "#":
				level += 1
			# Check bounds before accessing stripped[level]
			if level < stripped.length() and level == chapter_level and (stripped[level] == " " or stripped[level] == "\t"):
				# Save previous chapter if exists
				if current_chapter_id != "":
					_save_paragraph_for_chapter(current_chapter_id, file_path, current_paragraph_text, paragraph_start_line, line_num - 1)
					current_paragraph_text = ""

				# Create new chapter
				chapter_id_counter += 1
				current_chapter_id = "%s%d_%s" % [CHAPTER_ID_PREFIX, chapter_id_counter, hash_text(file_path)]
				var chapter_title := stripped.substr(level).strip_edges()
				var chapter_data := {
					"id": current_chapter_id,
					"title": chapter_title,
					"file": file_path,
					"level": level,
					"line": line_num,
					"paragraphs": []
				}
				chapters[current_chapter_id] = chapter_data
				file_data["chapters"].append(current_chapter_id)
				paragraph_start_line = line_num
			continue

		# Line-based paragraphs: each non-empty line is a separate paragraph
		if stripped != "":
			# Save previous paragraph if exists
			if current_paragraph_text != "":
				if current_chapter_id != "":
					_save_paragraph_for_chapter(current_chapter_id, file_path, current_paragraph_text, paragraph_start_line, line_num - 1)
				else:
					_save_paragraph_for_file(file_path, current_paragraph_text, paragraph_start_line, line_num - 1)
			# Start new paragraph
			current_paragraph_text = stripped
			paragraph_start_line = line_num
		else:
			# Empty line - save previous paragraph if exists
			if current_paragraph_text != "":
				if current_chapter_id != "":
					_save_paragraph_for_chapter(current_chapter_id, file_path, current_paragraph_text, paragraph_start_line, line_num - 1)
				else:
					_save_paragraph_for_file(file_path, current_paragraph_text, paragraph_start_line, line_num - 1)
				current_paragraph_text = ""

	# Save the last paragraph if it has content
	if current_paragraph_text != "":
		if current_chapter_id != "":
			_save_paragraph_for_chapter(current_chapter_id, file_path, current_paragraph_text, paragraph_start_line, line_num)
		else:
			_save_paragraph_for_file(file_path, current_paragraph_text, paragraph_start_line, line_num)


# Save a paragraph for a chapter
func _save_paragraph_for_chapter(chapter_id: String, file_path: String, text: String, start_line: int, end_line: int) -> void:
	text = text.strip_edges()
	if text == "":
		return

	var para_hash := hash_text(text)
	var para_id := "%s%s" % [PARAGRAPH_ID_PREFIX, para_hash.substr(0, 8)]

	# Store paragraph
	var paragraph_data := {
		"id": para_id,
		"hash": para_hash,
		"text": text,
		"file": file_path,
		"chapter": chapter_id,
		"start_line": start_line,
		"end_line": end_line
	}
	paragraphs[para_id] = paragraph_data

	# Add to chapter
	chapters[chapter_id]["paragraphs"].append(para_id)

	# Add to file
	files[file_path]["paragraphs"].append(para_id)


# Save a paragraph for a file (not in any chapter)
func _save_paragraph_for_file(file_path: String, text: String, start_line: int, end_line: int) -> void:
	text = text.strip_edges()
	if text == "":
		return

	var para_hash := hash_text(text)
	var para_id := "%s%s" % [PARAGRAPH_ID_PREFIX, para_hash.substr(0, 8)]

	# Store paragraph
	var paragraph_data := {
		"id": para_id,
		"hash": para_hash,
		"text": text,
		"file": file_path,
		"chapter": null,
		"start_line": start_line,
		"end_line": end_line
	}
	paragraphs[para_id] = paragraph_data

	# Add to file
	files[file_path]["paragraphs"].append(para_id)


# Get all files
func get_all_files() -> Array:
	return files.keys()


# Get all chapters
func get_all_chapters() -> Array:
	return chapters.keys()


# Get all paragraphs
func get_all_paragraphs() -> Array:
	return paragraphs.keys()


# Get chapters for a file
func get_chapters_for_file(file_path: String) -> Array:
	if not files.has(file_path):
		return []
	return files[file_path].get("chapters", [])


# Get paragraphs for a file
func get_paragraphs_for_file(file_path: String) -> Array:
	if not files.has(file_path):
		return []
	return files[file_path].get("paragraphs", [])


# Get paragraphs for a chapter
func get_paragraphs_for_chapter(chapter_id: String) -> Array:
	if not chapters.has(chapter_id):
		return []
	return chapters[chapter_id].get("paragraphs", [])


# Get paragraph by ID
func get_paragraph(paragraph_id: String) -> Dictionary:
	return paragraphs.get(paragraph_id, {})


# Get paragraph by hash
func get_paragraph_by_hash(paragraph_hash: String) -> Dictionary:
	for para_id in paragraphs:
		if paragraphs[para_id].get("hash", "") == paragraph_hash:
			return paragraphs[para_id]
	return {}


# Get chapter by ID
func get_chapter(chapter_id: String) -> Dictionary:
	return chapters.get(chapter_id, {})


# Get file by path
func get_file(file_path: String) -> Dictionary:
	return files.get(file_path, {})


# Check if a paragraph exists in the project
func has_paragraph(paragraph_hash: String) -> bool:
	return get_paragraph_by_hash(paragraph_hash).is_empty() == false


# Check if a paragraph exists in a specific file
func has_paragraph_in_file(paragraph_hash: String, file_path: String) -> bool:
	var paras := get_paragraphs_for_file(file_path)
	for para_id in paras:
		if paragraphs[para_id].get("hash", "") == paragraph_hash:
			return true
	return false


# Get all paragraph hashes in the project
func get_all_paragraph_hashes() -> Array:
	var hashes := []
	for para_id in paragraphs:
		hashes.append(paragraphs[para_id].get("hash", ""))
	return hashes


# Get all chapter hashes in the project
# Chapters are identified by their content hash (full file content)
func get_all_chapter_hashes() -> Array:
	var hashes := []
	for file_path in files:
		var file_data = files[file_path]
		if not file_data.is_empty():
			var file_hash = file_data.get("hash", "")
			if file_hash != "":
				hashes.append(file_hash)
	return hashes


# Get chapter containing a specific line in a file
func get_chapter_at_line(file_path: String, line_number: int) -> Dictionary:
	if not files.has(file_path):
		return {}

	var chapter_list := get_chapters_for_file(file_path)
	for chapter_id in chapter_list:
		var chapter = chapters[chapter_id]
		if line_number >= chapter.get("line", 0):
			# Check if there's a next chapter to compare against
			var next_chapter_line := 999999
			for other_id in chapter_list:
				if chapters[other_id].get("line", 0) > chapter.get("line", 0) and chapters[other_id].get("line", 0) < next_chapter_line:
					next_chapter_line = chapters[other_id].get("line", 0)
			if line_number < next_chapter_line:
				return chapter
	return {}


# Get paragraph at a specific line in a file
# Returns the paragraph data dictionary or empty dict if not found
func get_paragraph_at_line(file_path: String, line_number: int) -> Dictionary:
	if not files.has(file_path):
		return {}

	# Get all paragraphs for this file
	var para_ids := get_paragraphs_for_file(file_path)
	for para_id in para_ids:
		var para = paragraphs[para_id]
		var start_line: int = para.get("start_line", 0)
		var end_line: int = para.get("end_line", 0)
		if line_number >= start_line and line_number <= end_line:
			return para
	return {}


# Get paragraph hash at a specific line in a file (convenience method)
func get_paragraph_hash_at_line(file_path: String, line_number: int) -> String:
	var para := get_paragraph_at_line(file_path, line_number)
	return para.get("hash", "")


# Get all headings from a file (all levels, not just chapters)
# Returns array of heading dictionaries with: level, text, line, file
func get_all_headings_for_file(file_path: String) -> Array:
	var headings: Array = []
	if not files.has(file_path):
		return headings

	var content: String = files[file_path].get("content", "")
	if content == "":
		return headings

	var lines: Array = content.split("\n")
	var line_num: int = 0
	for line in lines:
		line_num += 1
		var stripped: String = line.strip_edges()
		if stripped.begins_with("#"):
			var level: int = 0
			while level < stripped.length() and stripped[level] == "#":
				level += 1
			if level < stripped.length() and (stripped[level] == " " or stripped[level] == "\t"):
				var text: String = stripped.substr(level).strip_edges()
				if text != "":
					headings.append({
					"level": level,
					"text": text,
					"line": line_num,
					"file": file_path
				})
	return headings


# Get all headings from all files in the project
func get_all_project_headings() -> Array:
	var all_headings: Array = []
	var all_files := get_all_files()
	all_files.sort()
	for file_path in all_files:
		var file_headings := get_all_headings_for_file(file_path)
		all_headings.append_array(file_headings)
	return all_headings


# Cleanup - remove entries that don't exist in the project anymore
func cleanup() -> void:
	var project_path := loaded_project_path
	if project_path == "":
		return

	var valid_files := FileUtils.get_all_text_files(project_path)
	var files_to_remove := []

	# Identify files to remove
	for file_path in files:
		if not valid_files.has(file_path):
			files_to_remove.append(file_path)

	# Remove files and their associated chapters/paragraphs
	for file_path in files_to_remove:
		# Remove chapters belonging to this file
		var chapter_ids = files[file_path].get("chapters", [])
		for chapter_id in chapter_ids:
			# Remove paragraphs belonging to this chapter
			var para_ids = chapters[chapter_id].get("paragraphs", [])
			for para_id in para_ids:
				paragraphs.erase(para_id)
			chapters.erase(chapter_id)
		files.erase(file_path)

	content_changed.emit()


# Force reload of current project
func reload() -> void:
	if loaded_project_path != "":
		load_project(loaded_project_path)


# Handle folder opened event
func _on_folder_opened(path: String) -> void:
	load_project(path)


# Handle file changed event
func _on_file_changed(file_path: String, _content: String) -> void:
	if file_path != "" and loaded_project_path != "":
		_add_file(file_path)
		content_changed.emit()


# Handle file saved event
func _on_file_saved(file_path: String) -> void:
	if file_path != "" and loaded_project_path != "":
		_add_file(file_path)
		content_changed.emit()


# Determine the heading level to use as chapter level
# Returns the level (1-6) that should be treated as chapters
func _determine_chapter_level(content: String) -> int:
	var level_counts: Dictionary = {}
	var lines := content.split("\n")

	# Count headings by level
	for line in lines:
		var stripped := line.strip_edges()
		if stripped.begins_with("#"):
			var level := 0
			while level < stripped.length() and stripped[level] == "#":
				level += 1
			# Check bounds before accessing stripped[level]
			if level >= 1 and level <= 6 and level < stripped.length() and (stripped[level] == " " or stripped[level] == "\t"):
				level_counts[level] = level_counts.get(level, 0) + 1

	# If no headings, default to level 1
	if level_counts.is_empty():
		return 1

	# If only one level, use that
	if level_counts.size() == 1:
		return level_counts.keys()[0]

	# Multiple levels - determine chapter level
	# Heuristic: if level 1 has very few headings (< 25% of total) and level 2 exists, use level 2
	# Otherwise, use level 1
	var total_headings := 0
	for count in level_counts.values():
		total_headings += count

	if total_headings == 0:
		return 1

	# If level 1 exists and has few headings, check if level 2 is more common
	if level_counts.has(1):
		var level1_count = level_counts[1]
		var level1_ratio = level1_count / total_headings

		# If level 1 has less than 25% of headings and level 2 exists with more
		if level1_ratio < 0.25 and level_counts.has(2):
			if level_counts[2] > level1_count:
				return 2

	# Default to level 1
	return 1


# Hash text using MD5
func hash_text(text: String) -> String:
	var hash_ctx := HashingContext.new()
	hash_ctx.start(HashingContext.HASH_MD5)
	hash_ctx.update(text.to_utf8_buffer())
	return hash_ctx.finish().hex_encode()
