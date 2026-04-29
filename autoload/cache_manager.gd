extends Node

# Cache manager for temporary data storage
# Creates and manages the .snorfeld cache folder

const CACHE_DIR_NAME := ".snorfeld"
const PARAGRAPH_DIR_NAME := "paragraph"
var current_cache_path := ""


func _ready() -> void:
	# Connect to folder_opened signal to auto-create cache
	GlobalSignals.folder_opened.connect(_on_folder_opened)
	# Connect to file_scanned signal to create cache files
	GlobalSignals.file_scanned.connect(_on_file_scanned)


func _on_folder_opened(path: String) -> void:
	current_cache_path = path.path_join(CACHE_DIR_NAME)
	create_folder(current_cache_path)


func _on_file_scanned(path: String, paragraphs: Array) -> void:
	# Get the base directory from the file path
	var dir_path := path.get_base_dir()
	var cache_path := dir_path.path_join(CACHE_DIR_NAME).path_join(PARAGRAPH_DIR_NAME)

	# Ensure cache exists for this directory
	if not DirAccess.dir_exists_absolute(cache_path):
		create_folder(cache_path)

	# Create a cache file for each paragraph
	for paragraph in paragraphs:
		var hash := _hash_paragraph(paragraph)
		var cache_file_path := cache_path.path_join("%s.json" % hash)

		# Only create if it doesn't exist
		if not _file_exists(cache_file_path):
			_create_cache_file(cache_file_path, paragraph)


# Check if file exists
func _file_exists(path: String) -> bool:
	var dir := DirAccess.open(path.get_base_dir())
	if dir:
		return dir.file_exists(path.get_file())
	return false


# Creates a simple hash from a paragraph string
func _hash_paragraph(paragraph: String) -> String:
	var hash := 0
	for i in range(paragraph.length()):
		var char_code := ord(paragraph[i])
		hash = (hash * 31 + char_code) % 0xFFFFFFFF
	return "%08x" % hash


# Creates an empty JSON cache file for a paragraph
func _create_cache_file(path: String, paragraph: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		# Write empty JSON structure with paragraph reference
		var data := {"paragraph_hash": _hash_paragraph(paragraph), "source": "", "text": paragraph}
		var json_str := JSON.stringify(data)
		file.store_string(json_str)
		file.close()
		return true
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

# Clears the cache folder and all its contents
func clear_cache(base_path: String) -> bool:
	var cache_path := base_path.path_join(CACHE_DIR_NAME)

	if DirAccess.dir_exists_absolute(cache_path):
		var dir := DirAccess.open(cache_path)

		if dir:
			# Remove all files and subdirectories
			dir.list_dir_begin()
			var file_name := ""
			while file_name != "":
				file_name = dir.get_next()
				if file_name != "":
					var full_path := cache_path.path_join(file_name)
					if dir.current_is_dir():
						# Recursively remove subdirectory
						var sub_dir := DirAccess.open(full_path)
						if sub_dir:
							sub_dir.remove_dir_recursive(full_path)
					else:
						dir.remove_file(full_path)
				dir.list_dir_end()

			# Remove the cache directory itself
			var err: int = dir.remove_dir(cache_path)
			if err == OK:
				current_cache_path = ""
				return true
			else:
				push_error("Failed to remove cache directory: %s" % [cache_path])
				return false
		else:
			push_error("Failed to open cache directory for clearing: %s" % [cache_path])
			return false
	else:
		# Cache doesn't exist, nothing to clear
		return true


# Gets the current cache path
func get_cache_path() -> String:
	return current_cache_path
