class_name FileUtils
extends RefCounted
## FileUtils - Utility class for file operations
## Usage: FileUtils.read_file(path), FileUtils.write_file(path, content), etc.

## File reading

static func read_file(file_path: String) -> String:
	if not file_exists(file_path):
		return ""
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return ""
	var content := file.get_as_text()
	file.close()
	return content

## File writing

static func write_file(file_path: String, content: String) -> bool:
	# Ensure parent directory exists
	var dir_path := file_path.get_base_dir()
	if not dir_exists(dir_path):
		var err := DirAccess.make_dir_recursive_absolute(dir_path)
		if err != OK:
			return false

	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(content)
	file.close()
	return true

## File deletion

static func remove_file(file_path: String) -> bool:
	if not file_exists(file_path):
		return false
	var err := DirAccess.remove_absolute(file_path)
	return err == OK

## File existence check

static func file_exists(path: String) -> bool:
	return FileAccess.file_exists(path)

## Directory existence check

static func dir_exists(path: String) -> bool:
	return DirAccess.dir_exists_absolute(path)

## Get file modification time

static func get_modified_time(path: String) -> float:
	return FileAccess.get_modified_time(path)

## Ensure directory exists

static func ensure_directory(path: String) -> bool:
	if dir_exists(path):
		return true
	var err := DirAccess.make_dir_recursive_absolute(path)
	return err == OK

## Get all files in a directory with a specific extension
static func get_files_by_extension(base_path: String, extension: String) -> Array:
	var files := []
	if not dir_exists(base_path):
		return files
	var dir: DirAccess = DirAccess.open(base_path)
	if not dir:
		return files
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if file_name.ends_with(extension):
			files.append(base_path.path_join(file_name))
		file_name = dir.get_next()
	dir.list_dir_end()
	return files

# Text file extensions (same as file_explorer.gd)
const TEXT_FILE_EXTENSIONS: Array = [
	'txt', 'md', 'yml', 'yaml', 'json', 'csv', 'html', 'htm', 'xml',
	'js', 'ts', 'py', 'rb', 'go', 'rs', 'java', 'c', 'cpp', 'h', 'hpp',
	'sh', 'sql', 'log', 'cfg', 'ini', 'toml', 'tex', 'rst'
]

## Recursive text file scanning
static func get_all_text_files(base_path: String) -> Array:
	var text_files := []
	var dir: DirAccess = DirAccess.open(base_path)
	if not dir:
		return text_files

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		var full_path: String = base_path.path_join(file_name)
		if dir.current_is_dir():
			# Skip .snorfeld cache directory and other hidden dirs
			if not file_name.begins_with("."):
				text_files += get_all_text_files(full_path)
		else:
			# Only include text files
			if _is_text_file_extension(file_name):
				text_files.append(full_path)
		file_name = dir.get_next()
	dir.list_dir_end()
	# Sort files alphabetically for consistent processing order
	text_files.sort()
	return text_files


## Check if a file has a text file extension
static func _is_text_file_extension(file_path: String) -> bool:
	for ext: String in TEXT_FILE_EXTENSIONS:
		if file_path.to_lower().ends_with(".%s" % ext):
			return true
	return false
