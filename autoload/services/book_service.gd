extends Node
## BookService - Central content model for the project
## Maintains a unified view of all files, chapters, and paragraphs

# Project content structure:
# - files: Dictionary of file_path -> FileData
# - chapters: Dictionary of chapter_id -> ChapterData
# - paragraphs: Dictionary of paragraph_hash -> ParagraphData

const CHAPTER_ID_PREFIX := "chap_"
const PARAGRAPH_ID_PREFIX := "para_"

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
	var file_hash := _hash_text(content)

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

		# Check for chapter heading (level 1)
		if stripped.begins_with("#") and stripped.length() > 1:
			var level := 0
			while level < stripped.length() and stripped[level] == "#":
				level += 1
			if level == 1 and (stripped[level] == " " or stripped[level] == "\t"):
				# Save previous chapter if exists
				if current_chapter_id != "":
					_save_paragraph_for_chapter(current_chapter_id, file_path, current_paragraph_text, paragraph_start_line, line_num - 1)
					current_paragraph_text = ""

				# Create new chapter
				chapter_id_counter += 1
				current_chapter_id = "%s%d_%s" % [CHAPTER_ID_PREFIX, chapter_id_counter, _hash_text(file_path)]
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

		# Accumulate paragraph text (separated by double newlines)
		if current_chapter_id != "":
			if current_paragraph_text == "":
				paragraph_start_line = line_num
			else:
				current_paragraph_text += "\n"
			current_paragraph_text += line
		else:
			# Outside chapters, still track paragraphs for the file
			if current_paragraph_text == "":
				paragraph_start_line = line_num
			else:
				current_paragraph_text += "\n"
			current_paragraph_text += line

	# Save the last paragraph
	if current_chapter_id != "":
		_save_paragraph_for_chapter(current_chapter_id, file_path, current_paragraph_text, paragraph_start_line, line_num)
	else:
		_save_paragraph_for_file(file_path, current_paragraph_text, paragraph_start_line, line_num)


# Save a paragraph for a chapter
func _save_paragraph_for_chapter(chapter_id: String, file_path: String, text: String, start_line: int, end_line: int) -> void:
	text = text.strip_edges()
	if text == "":
		return

	var para_hash := _hash_text(text)
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

	var para_hash := _hash_text(text)
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


# Hash text using MD5
func _hash_text(text: String) -> String:
	var hash_ctx := HashingContext.new()
	hash_ctx.start(HashingContext.HASH_MD5)
	hash_ctx.update(text.to_utf8_buffer())
	return hash_ctx.finish().hex_encode()
