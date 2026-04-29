extends Node

# Cache manager for temporary data storage
# Creates and manages the .snorfeld cache folder

const CACHE_DIR_NAME := ".snorfeld"
var current_cache_path := ""


func _ready() -> void:
	print("Starting caching manager...")
	# Connect to folder_opened signal to auto-create cache
	GlobalSignals.folder_opened.connect(_on_folder_opened)


func _on_folder_opened(path: String) -> void:
	current_cache_path = path.path_join(CACHE_DIR_NAME)
	create_cache(path)


# Creates the cache folder for the given directory
func create_cache(base_path: String) -> bool:
	var cache_path := base_path.path_join(CACHE_DIR_NAME)

	if not DirAccess.dir_exists_absolute(cache_path):
		var err: int = DirAccess.make_dir_recursive_absolute(cache_path)
		if err == OK:
			current_cache_path = cache_path
			return true
		else:
			push_error("Failed to create cache directory: %s" % [cache_path])
			return false
	else:
		current_cache_path = cache_path
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
