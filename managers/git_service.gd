extends Node

# gdlint:ignore-file:file-length,god-class-functions,long-function,high-complexity
## GitService - Core git operations using OS.execute()
## Uses 'which' (Unix) or 'where' (Windows) to locate Git executable.

# --- State ---
var git_root: String = ""
var is_git_repo_cached: bool = false
var file_status_cache: Dictionary = {}
var last_status_refresh: float = 0.0
const STATUS_REFRESH_COOLDOWN: float = 1.0
var git_executable: String = ""
const CONFIG_FILE: String = "user://git_config.cfg"

# Git status format: first N characters are status indicators (staged, unstaged)
const GIT_STATUS_PREFIX_LENGTH: int = 3

### Initialization

func _ready():
	_load_git_config()
	if git_executable == "":
		_detect_git_executable()

	# Connect to folder opened signal
	EventBus.folder_opened.connect(_on_folder_opened)
	EventBus.file_saved.connect(_on_file_saved)
	EventBus.file_changed.connect(_on_file_changed)

### Configuration

func _load_git_config() -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load(CONFIG_FILE) == OK:
		git_executable = config.get_value("git", "executable", "")

func _save_git_config() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("git", "executable", git_executable)
	config.save(CONFIG_FILE)

func set_git_executable(path: String) -> void:
	if _verify_git_executable(path):
		git_executable = path
		_save_git_config()
	else:
		git_executable = ""
		_detect_git_executable()

### Git Executable Detection

func _verify_git_executable(path: String) -> bool:
	var output: Array = []
	var result: int = OS.execute(path, ['--version'], output)
	return result == 0

func _detect_git_executable() -> bool:
	var output: Array = []
	var result: int
	if OS.get_name() == "Windows":
		result = OS.execute('where', ['git'], output)
	else:
		result = OS.execute('which', ['git'], output)
	if result == 0 and output.size() > 0:
		git_executable = output[0].strip_edges()
		_save_git_config()
		return true
	git_executable = ""
	return false

### Repository Detection

func is_git_repo(path: String) -> bool:
	# Check if the path or any parent contains a .git directory
	return find_git_root(path) != ""

func find_git_root(path: String) -> String:
	var current: String = path.get_base_dir()
	while current != "":
		if FileUtils.dir_exists(current.path_join(".git")):
			return current
		current = current.get_base_dir()
		if current in ["/", ":/", ":\\"]:
			break
	return ""

func get_git_root() -> String:
	return git_root

### Git Command Execution

func _execute_git_command(args: Array, cwd: String = "") -> Array:
	if git_executable == "":
		push_error("[GitService] Git executable not configured")
		return ["", "Git executable not configured"]

	var full_args: Array = args.duplicate()
	if cwd != "":
		full_args.insert(0, cwd)
		full_args.insert(0, '-C')

	var output: Array = []
	var exit_code: int = OS.execute(git_executable, full_args, output)

	if exit_code != 0 and output.size() == 0:
		return ["", "Command failed with exit code: %d" % exit_code]
	elif output.size() > 0:
		return [output[0], ""]
	else:
		return ["", ""]

func _execute_git_command_simple(args: Array, cwd: String = "") -> bool:
	return _execute_git_command(args, cwd)[1] == ""


### Git Operation Helper

## Execute a git operation with standard event handling and error reporting
## @param operation_name Human-readable operation name for events
## @param args Git command arguments
## @param cwd Working directory (defaults to git_root)
## @param refresh After clearing cache, call refresh_status
## @return bool true on success, false on error
func _execute_git_operation(
	operation_name: String,
	args: Array,
	cwd: String = "",
	refresh: bool = false
) -> bool:
	var work_dir: String = cwd if cwd != "" else git_root
	if not git_executable or not work_dir:
		EventBus.git_operation_completed.emit(false, "Not a git repository")
		return false

	EventBus.git_operation_started.emit(operation_name)

	if not _execute_git_command_simple(args, work_dir):
		EventBus.git_operation_completed.emit(false, "Failed to %s" % operation_name)
		return false

	file_status_cache.clear()

	if refresh:
		refresh_status()

	EventBus.git_operation_completed.emit(true, "%s successful" % operation_name.capitalize())
	return true


### Helper Functions

## Determine git change type from status characters
func _determine_change_type(staged_char: String, unstaged_char: String, _file_path: String) -> String:
	# Renamed files have format: "X Y -> new_path" - path already cleaned by caller
	# Check untracked first (?? means new untracked file)
	if staged_char == "?" and unstaged_char == "?":
		return "untracked"
	# Deleted
	if staged_char == "D" or unstaged_char == "D":
		return "deleted"
	# Conflicted
	if staged_char == "U" or unstaged_char == "U":
		return "conflicted"
	# Modified (unstaged or staged)
	if unstaged_char == "M" or (unstaged_char == " " and staged_char == "M"):
		return "modified"
	# Added/Staged (new file added to git)
	if unstaged_char == "A" or (unstaged_char == " " and staged_char == "A"):
		return "staged"
	# Default fallback
	return "modified"

### Core Git Operations

func init_git_repo(path: String) -> bool:
	if git_executable == "":
		EventBus.git_operation_completed.emit(false, "Git executable not found")
		return false

	EventBus.git_operation_started.emit("init")

	if is_git_repo(path):
		git_root = find_git_root(path)
		is_git_repo_cached = true
		EventBus.git_operation_completed.emit(true, "Already a git repository")
		EventBus.git_repo_changed.emit(true)
		return true

	if not _execute_git_command_simple(["init"], path):
		EventBus.git_operation_completed.emit(false, "Failed to initialize git repo")
		return false

	git_root = path
	is_git_repo_cached = true
	ensure_snorfeld_in_gitignore()
	EventBus.git_operation_completed.emit(true, "Git repository initialized")
	EventBus.git_repo_changed.emit(true)
	return true

func get_status(base_path: String = "") -> Dictionary:
	var repo_path: String = _get_repo_path(base_path)
	if repo_path == "":
		return {"error": "No git repository"}

	var output: Array = _execute_git_command(["status", "--porcelain", "-u"], repo_path)
	if output[0] == "":
		push_error("[GitService] %s" % output[1])
		return {"error": output[1]}

	var status: Dictionary = {"files": []}
	_parse_status_output(output[0], status)
	return status


func _get_repo_path(base_path: String) -> String:
	if git_executable == "":
		push_error("[GitService] Git not found")
		return ""
	return base_path if base_path else git_root


func _parse_status_output(output: String, status: Dictionary) -> void:
	for line in output.split("\n"):
		if line.length() < GIT_STATUS_PREFIX_LENGTH:
			continue
		var file_info: Dictionary = _parse_status_line(line)
		if file_info:
			status["files"].append(file_info)


func _parse_status_line(line: String) -> Dictionary:
	var staged_char: String = line[0]
	var unstaged_char: String = line[1]
	var file_path: String = line.substr(GIT_STATUS_PREFIX_LENGTH)

	# Handle renamed files
	if " -> " in file_path:
		file_path = file_path.split(" -> ")[1]

	var is_staged: bool = staged_char != " " and not (staged_char == "?" and unstaged_char == "?")
	var change_type: String = _determine_change_type(staged_char, unstaged_char, file_path)

	return {"path": file_path, "change_type": change_type, "staged": is_staged}


func get_file_status(file_path: String) -> String:
	if file_status_cache.has(file_path):
		return file_status_cache[file_path]

	if not git_root:
		return "not_git"

	var status: Dictionary = get_status()
	if status.has("error"):
		return "error"

	for file_info in status["files"]:
		if file_info["path"] == file_path:
			file_status_cache[file_path] = file_info["change_type"]
			return file_info["change_type"]

	file_status_cache[file_path] = "clean"
	return "clean"

func refresh_status(base_path: String = "") -> void:
	var repo_path: String = base_path if base_path else git_root
	if not repo_path:
		return

	var status: Dictionary = get_status(repo_path)
	if not status.has("error"):
		EventBus.git_status_updated.emit()
		file_status_cache.clear()
		for file_info in status["files"]:
			file_status_cache[file_info["path"]] = file_info["change_type"]
			EventBus.file_status_changed.emit(file_info["path"], file_info["change_type"])

### Diff Operations

func get_file_content_from_git(file_path: String) -> String:
	if not git_executable or not git_root:
		return ""
	var relative_path: String = _make_path_relative(file_path)
	var result: Array = _execute_git_command(["show", "HEAD:" + relative_path], git_root)
	if result[1] == "":
		return result[0]
	return ""

### Staging Operations

func stage_file(file_path: String) -> bool:
	return _execute_git_operation(
		"stage", ["add", _make_path_relative(file_path)], "", true
	)

func stage_all() -> bool:
	return _execute_git_operation("stage_all", ["add", "-A"], "", true)

func unstage_file(file_path: String) -> bool:
	return _execute_git_operation(
		"unstage", ["restore", "--staged", "--", _make_path_relative(file_path)], "", true
	)

### Commit Operations

func commit(message: String) -> bool:
	if message == "":
		EventBus.git_operation_completed.emit(false, "Empty commit message")
		return false
	return _execute_git_operation("commit", ["commit", "-m", message], "", true)

### Push/Pull/Fetch Operations

func push(remote: String = "origin", branch: String = "") -> bool:
	var args: Array = ["push", remote]
	if branch:
		args.append(branch)
	return _execute_git_operation("push", args, "", false)

func pull(remote: String = "origin", branch: String = "") -> bool:
	var args: Array = ["pull", remote]
	if branch:
		args.append(branch)
	return _execute_git_operation("pull", args, "", true)

func fetch(remote: String = "origin") -> bool:
	return _execute_git_operation("fetch", ["fetch", remote], "", false)

### .gitignore Management

func add_to_gitignore(pattern: String) -> bool:
	if not git_root:
		return false

	var gitignore_path: String = git_root.path_join(".gitignore")
	var content: String = FileUtils.read_file(gitignore_path)

	if pattern in content:
		return true

	content += "\n%s\n" % pattern
	if FileUtils.write_file(gitignore_path, content):
		return true
	return false

func ensure_snorfeld_in_gitignore() -> bool:
	return add_to_gitignore(".snorfeld")

### Helper Methods

func _make_path_relative(file_path: String) -> String:
	if not git_root:
		return file_path

	var normalized_root: String = git_root.replace("\\", "/").replace("//", "/")
	var normalized_path: String = file_path.replace("\\", "/").replace("//", "/")

	if normalized_path.begins_with(normalized_root):
		var relative: String = normalized_path.substr(normalized_root.length())
		return relative.trim_prefix("/")

	return file_path

### Event Handlers

func _on_folder_opened(path: String):
	git_root = find_git_root(path)
	is_git_repo_cached = git_root != ""
	EventBus.git_repo_changed.emit(is_git_repo_cached)
	if is_git_repo_cached:
		ensure_snorfeld_in_gitignore()
		refresh_status(path)

func _on_file_saved(_path: String):
	if is_git_repo_cached:
		file_status_cache.clear()
		call_deferred("refresh_status")

func _on_file_changed(_path: String, _content: String):
	if is_git_repo_cached:
		file_status_cache.clear()
		call_deferred("refresh_status")
