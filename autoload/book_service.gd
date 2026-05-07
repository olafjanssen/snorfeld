extends Node
## BookService - Central content model for the project
## Maintains a view of all files, chapters, and paragraphs

# gdlint:ignore-file:file-length,god-class-functions,deep-nesting,long-function,magic-number,long-line,too-many-params

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
	var text_files: Array = FileUtils.get_all_text_files(project_path)

	for file_path in text_files:
		_add_file(file_path)


# Add or update a file in the model
func _add_file(file_path: String) -> void:
	var content: String = FileUtils.read_file(file_path)
	if content == "":
		return

	var file_data: Dictionary = {
		"path": file_path,
		"hash": hash_text(content),
		"content": content,
		"chapters": [],
		"paragraphs": [],
		"modified_time": FileUtils.get_modified_time(file_path)
	}
	files[file_path] = file_data

	var chapter_level: int = _determine_chapter_level(content)
	var chapter_id_counter: int = 0
	var current_chapter_id: String = ""
	var lines: Array = content.split("\n")
	var paragraph_start_line: int = 0
	var current_paragraph_text: String = ""

	for i in range(lines.size()):
		var line_num: int = i + 1
		var line: String = lines[i]
		var stripped: String = line.strip_edges()

		if _is_chapter_heading(stripped, chapter_level):
			var level: int = _count_hashes(stripped)
			_save_previous_paragraph(current_chapter_id, file_path, current_paragraph_text, paragraph_start_line, line_num - 1)
			current_chapter_id = _create_chapter(file_path, stripped, level, line_num, chapter_id_counter, file_data)
			chapter_id_counter += 1
			paragraph_start_line = line_num
			current_paragraph_text = ""
			continue

		# Line-based paragraphs: each non-empty line is a separate paragraph
		if stripped != "":
			# Save previous paragraph if exists
			_save_previous_paragraph(current_chapter_id, file_path, current_paragraph_text, paragraph_start_line, line_num - 1)
			# Start new paragraph
			current_paragraph_text = stripped
			paragraph_start_line = line_num
		else:
			# Empty line - save previous paragraph if exists
			_save_previous_paragraph(current_chapter_id, file_path, current_paragraph_text, paragraph_start_line, line_num - 1)
			current_paragraph_text = ""

	# Save the last paragraph if it has content
	if current_paragraph_text != "":
		_save_paragraph_for_chapter_or_file(current_chapter_id, file_path, current_paragraph_text, paragraph_start_line, lines.size())


## Check if line is a chapter heading at the expected level
func _is_chapter_heading(stripped: String, chapter_level: int) -> bool:
	if not stripped.begins_with("#") or stripped.length() <= 1:
		return false
	var level: int = 0
	while level < stripped.length() and stripped[level] == "#":
		level += 1
	return level == chapter_level and level < stripped.length() and (stripped[level] == " " or stripped[level] == "\t")


## Count number of # characters at start of string
func _count_hashes(stripped: String) -> int:
	var level: int = 0
	while level < stripped.length() and stripped[level] == "#":
		level += 1
	return level


## Create a new chapter and add to file data
func _create_chapter(file_path: String, heading: String, level: int, line_num: int, chapter_id_counter: int, file_data: Dictionary) -> String:
	chapter_id_counter += 1
	var chapter_id: String = "%s%d_%s" % [CHAPTER_ID_PREFIX, chapter_id_counter, hash_text(file_path)]
	var chapter_title: String = heading.substr(level).strip_edges()
	var chapter_data: Dictionary = {
		"id": chapter_id,
		"title": chapter_title,
		"file": file_path,
		"level": level,
		"line": line_num,
		"paragraphs": []
	}
	chapters[chapter_id] = chapter_data
	file_data["chapters"].append(chapter_id)
	return chapter_id


## Save previous paragraph if it exists
func _save_previous_paragraph(current_chapter_id: String, file_path: String, current_paragraph_text: String, paragraph_start_line: int, end_line: int) -> void:
	if current_paragraph_text == "":
		return
	if current_chapter_id != "":
		_save_paragraph_for_chapter(current_chapter_id, file_path, current_paragraph_text, paragraph_start_line, end_line)
	else:
		_save_paragraph_for_file(file_path, current_paragraph_text, paragraph_start_line, end_line)


## Save paragraph to chapter or file
func _save_paragraph_for_chapter_or_file(current_chapter_id: String, file_path: String, current_paragraph_text: String, paragraph_start_line: int, end_line: int) -> void:
	if current_chapter_id != "":
		_save_paragraph_for_chapter(current_chapter_id, file_path, current_paragraph_text, paragraph_start_line, end_line)
	else:
		_save_paragraph_for_file(file_path, current_paragraph_text, paragraph_start_line, end_line)


# Save a paragraph for a chapter
func _save_paragraph_for_chapter(chapter_id: String, file_path: String, text: String, start_line: int, end_line: int) -> void:
	text = text.strip_edges()
	if text == "":
		return

	var para_hash: String = hash_text(text)
	var para_id: String = "%s%s" % [PARAGRAPH_ID_PREFIX, para_hash.substr(0, 8)]

	# Store paragraph
	var paragraph_data: Dictionary = {
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

	var para_hash: String = hash_text(text)
	var para_id: String = "%s%s" % [PARAGRAPH_ID_PREFIX, para_hash.substr(0, 8)]

	# Store paragraph
	var paragraph_data: Dictionary = {
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
	var chapters_list: Array = files[file_path].get("chapters")
	return chapters_list if chapters_list != null else []


# Get paragraphs for a file
func get_paragraphs_for_file(file_path: String) -> Array:
	if not files.has(file_path):
		return []
	var paragraphs_list: Array = files[file_path].get("paragraphs")
	return paragraphs_list if paragraphs_list != null else []


# Get paragraphs for a chapter
func get_paragraphs_for_chapter(chapter_id: String) -> Array:
	if not chapters.has(chapter_id):
		return []
	var paragraphs_list: Array = chapters[chapter_id].get("paragraphs")
	return paragraphs_list if paragraphs_list != null else []


# Get paragraph by ID
func get_paragraph(paragraph_id: String) -> Dictionary:
	var paragraph: Dictionary = paragraphs.get(paragraph_id)
	return paragraph if paragraph != null else {}


# Get paragraph by hash
func get_paragraph_by_hash(paragraph_hash: String) -> Dictionary:
	for para_id in paragraphs:
		var para_hash: String = paragraphs[para_id].get("hash")
		if para_hash != null and para_hash == paragraph_hash:
			return paragraphs[para_id]
	return {}


# Get chapter by ID
func get_chapter(chapter_id: String) -> Dictionary:
	return chapters[chapter_id] if chapters.has(chapter_id) else {}


# Get file by path
func get_file(file_path: String) -> Dictionary:
	return files[file_path] if files.has(file_path) else {}


# Check if a paragraph exists in the project
func has_paragraph(paragraph_hash: String) -> bool:
	return get_paragraph_by_hash(paragraph_hash).is_empty() == false


# Check if a paragraph exists in a specific file
func has_paragraph_in_file(paragraph_hash: String, file_path: String) -> bool:
	var paras: Array = get_paragraphs_for_file(file_path)
	for para_id in paras:
		var para_hash: String = paragraphs[para_id].get("hash")
		if para_hash != null and para_hash == paragraph_hash:
			return true
	return false


# Get all paragraph hashes in the project
func get_all_paragraph_hashes() -> Array:
	var hashes: Array = []
	for para_id in paragraphs:
		var para_hash: String = paragraphs[para_id].get("hash")
		if para_hash != null:
			hashes.append(para_hash)
	return hashes


# Get all chapter hashes in the project
# Chapters are identified by their content hash (full file content)
func get_all_chapter_hashes() -> Array:
	var hashes: Array = []
	for file_path in files:
		var file_data: Dictionary = files[file_path]
		if not file_data.is_empty():
			var file_hash: String = file_data.get("hash")
			if file_hash != null and file_hash != "":
				hashes.append(file_hash)
	return hashes


# Get chapter containing a specific line in a file
func get_chapter_at_line(file_path: String, line_number: int) -> Dictionary:
	if not files.has(file_path):
		return {}

	var chapter_list: Array = get_chapters_for_file(file_path)
	for chapter_id in chapter_list:
		var chapter: Dictionary = chapters[chapter_id]
		var chapter_line: int = chapter.get("line")
		if chapter_line == null:
			continue
		if line_number >= chapter_line:
			# Check if there's a next chapter to compare against
			var next_chapter_line: int = 999999
			for other_id in chapter_list:
				var other_line: int = chapters[other_id].get("line")
				if other_line != null and other_line > chapter_line and other_line < next_chapter_line:
					next_chapter_line = other_line
			if line_number < next_chapter_line:
				return chapter
	return {}


# Get paragraph at a specific line in a file
# Returns the paragraph data dictionary or empty dict if not found
func get_paragraph_at_line(file_path: String, line_number: int) -> Dictionary:
	if not files.has(file_path):
		return {}

	# Get all paragraphs for this file
	var para_ids: Array = get_paragraphs_for_file(file_path)
	for para_id in para_ids:
		var para: Dictionary = paragraphs[para_id]
		var start_line: int = para.get("start_line")
		var end_line: int = para.get("end_line")
		if start_line != null and end_line != null and line_number >= start_line and line_number <= end_line:
			return para
	return {}


# Get paragraph hash at a specific line in a file (convenience method)
func get_paragraph_hash_at_line(file_path: String, line_number: int) -> String:
	var para: Dictionary = get_paragraph_at_line(file_path, line_number)
	var hash_val: String = para.get("hash")
	return hash_val if hash_val != null else ""


# Get all headings from a file (all levels, not just chapters)
# Returns array of heading dictionaries with: level, text, line, file
func get_all_headings_for_file(file_path: String) -> Array:
	var headings: Array = []
	if not files.has(file_path):
		return headings

	var content: String = files[file_path].get("content")
	if content == null or content == "":
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
	var all_files: Array = get_all_files()
	all_files.sort()
	for file_path in all_files:
		var file_headings: Array = get_all_headings_for_file(file_path)
		all_headings.append_array(file_headings)
	return all_headings


# Cleanup - remove entries that don't exist in the project anymore
func cleanup() -> void:
	var project_path: String = loaded_project_path
	if project_path == "":
		return

	var valid_files: Array = FileUtils.get_all_text_files(project_path)
	var files_to_remove: Array = []

	# Identify files to remove
	for file_path in files:
		if not valid_files.has(file_path):
			files_to_remove.append(file_path)

	# Remove files and their associated chapters/paragraphs
	for file_path in files_to_remove:
		# Remove chapters belonging to this file
		var chapter_ids: Array = files[file_path].get("chapters")
		if chapter_ids != null:
			for chapter_id in chapter_ids:
				# Remove paragraphs belonging to this chapter
				var para_ids: Array = chapters[chapter_id].get("paragraphs")
				if para_ids != null:
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
	var level_counts: Dictionary = _count_headings_by_level(content)

	if level_counts.is_empty():
		return 1

	if level_counts.size() == 1:
		return level_counts.keys()[0]

	return _determine_chapter_level_from_counts(level_counts)


## Count headings by level in content
func _count_headings_by_level(content: String) -> Dictionary:
	var level_counts: Dictionary = {}
	var lines: Array = content.split("\n")

	for line in lines:
		var stripped: String = line.strip_edges()
		if stripped.begins_with("#"):
			var level: int = _get_heading_level(stripped)
			if level >= 1 and level <= 6:
				var current = level_counts.get(level)
				level_counts[level] = (current as int) + 1 if current != null else 1

	return level_counts


## Get heading level from a line (returns 0 if not a valid heading)
func _get_heading_level(stripped: String) -> int:
	var level: int = 0
	while level < stripped.length() and stripped[level] == "#":
		level += 1
	# Check bounds before accessing stripped[level]
	if level >= 1 and level <= 6 and level < stripped.length() and (stripped[level] == " " or stripped[level] == "\t"):
		return level
	return 0


## Determine chapter level from heading counts
func _determine_chapter_level_from_counts(level_counts: Dictionary) -> int:
	var total_headings: int = 0
	for count in level_counts.values():
		total_headings += count

	if total_headings == 0:
		return 1

	if level_counts.has(1):
		var level1_count: int = level_counts[1]
		var level1_ratio: float = level1_count * 1.0 / total_headings

		if level1_ratio < 0.25 and level_counts.has(2) and level_counts[2] > level1_count:
			return 2

	return 1


# Hash text using MD5
func hash_text(text: String) -> String:
	var hash_ctx := HashingContext.new()
	hash_ctx.start(HashingContext.HASH_MD5)
	hash_ctx.update(text.to_utf8_buffer())
	return hash_ctx.finish().hex_encode()
