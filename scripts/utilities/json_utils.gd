class_name JsonUtils
extends RefCounted
## JsonUtils - Utility class for JSON operations
## Usage: JsonUtils.parse_json(str), JsonUtils.stringify(data), etc.

## Parse JSON string to Dictionary
## @param json_string The JSON string to parse
## @return Dictionary with parsed data, or empty dict on error
static func parse_json(json_string: String) -> Dictionary:
	var json := JSON.new()
	var error := json.parse(json_string)
	if error == OK:
		return json.get_data()
	else:
		push_error("JSON parse error at line %d: %s" % [json.get_error_line(), json.get_error_message()])
		return {}

## Stringify Dictionary to JSON string
## @param data The Dictionary to serialize
## @param pretty If true, format with indentation
## @return JSON string representation
static func stringify_json(data: Dictionary, pretty: bool = false) -> String:
	if pretty:
		return JSON.stringify(data, "	")
	return JSON.stringify(data)

## Parse JSON file to Dictionary
## @param file_path Path to the JSON file
## @return Dictionary with parsed data, or empty dict on error
static func parse_json_file(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		push_error("JSON file not found: %s" % file_path)
		return {}
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("Failed to open JSON file: %s" % file_path)
		return {}
	var content := file.get_as_text()
	file.close()
	return parse_json(content)

## Write Dictionary to JSON file
## @param file_path Path to write the JSON file
## @param data The Dictionary to serialize and write
## @param pretty If true, format with indentation
## @return bool true on success, false on error
static func write_json_file(file_path: String, data: Dictionary, pretty: bool = false) -> bool:
	var json_string := stringify_json(data, pretty)
	if json_string == "":
		return false

	# Ensure parent directory exists
	var dir_path := file_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		var err := DirAccess.make_dir_recursive_absolute(dir_path)
		if err != OK:
			push_error("Failed to create directory: %s" % dir_path)
			return false

	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to open file for writing: %s" % file_path)
		return false
	file.store_string(json_string)
	file.close()
	return true
