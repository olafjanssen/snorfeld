extends Node
# Cache manager for temporary data storage
# Creates and manages the .snorfeld cache folder

const CACHE_DIR_NAME := ".snorfeld"
const PARAGRAPH_DIR_NAME := "paragraph"
var current_cache_path := ""

func _ready() -> void:
	# Connect to folder_opened signal to auto-create cache
	GlobalSignals.folder_opened.connect(_on_folder_opened)

func _on_folder_opened(path: String) -> void:
	print("[CacheManager] Folder opened: %s" % path)
	current_cache_path = path.path_join(CACHE_DIR_NAME)
	print("[CacheManager] Cache path set to: %s" % current_cache_path)
	create_folder(current_cache_path)

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


# Recursively removes a directory and all its contents
func _remove_directory(path: String) -> bool:
	var dir = DirAccess.open(path)
	if not dir:
		push_error("[CacheManager] Failed to open directory for removal: %s" % path)
		return false

	print("[CacheManager] Removing directory: %s" % path)
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		var full_path = path.path_join(file_name)
		if dir.current_is_dir():
			# Recursively remove subdirectory
			if not _remove_directory(full_path):
				dir.list_dir_end()
				return false
		else:
			# Remove file
			print("[CacheManager] Removing file: %s" % full_path)
			if DirAccess.remove_absolute(full_path) != OK:
				push_error("[CacheManager] Failed to remove file: %s" % full_path)
				dir.list_dir_end()
				return false
		file_name = dir.get_next()
	dir.list_dir_end()

	# Remove the now-empty directory
	print("[CacheManager] Removing empty directory: %s" % path)
	if DirAccess.remove_absolute(path) != OK:
		push_error("[CacheManager] Failed to remove directory: %s" % path)
		return false
	return true


# Clears the cache folder and all its contents
func clear_cache() -> bool:
	var cache_path := current_cache_path

	if DirAccess.dir_exists_absolute(cache_path):
		print("[CacheManager] Clearing cache at: %s" % cache_path)
		if _remove_directory(cache_path):
			current_cache_path = ""
			print("[CacheManager] Cache cleared successfully")
			return true
		else:
			push_error("[CacheManager] Failed to clear cache directory: %s" % [cache_path])
			return false
	else:
		print("[CacheManager] Cache doesn't exist, nothing to clear")
		return true


# Gets the current cache path
func get_cache_path() -> String:
	return current_cache_path
