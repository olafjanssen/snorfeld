extends Node
## GitManager - Core git operations using OS.execute()
## Uses 'which' (Unix) or 'where' (Windows) to locate Git executable.

# --- State ---
var git_root: String = ""
var is_git_repo_cached: bool = false
var file_status_cache: Dictionary = {}
var last_status_refresh: float = 0.0
const STATUS_REFRESH_COOLDOWN: float = 1.0
var git_executable: String = ""
const CONFIG_FILE: String = "user://git_config.cfg"

### Initialization

func _ready():
	print("GitManager: _ready() called")
	_load_git_config()
	print("GitManager: git_executable after config load: ", git_executable)
	if git_executable == "":
		print("GitManager: git_executable is empty, detecting...")
		_detect_git_executable()
		print("GitManager: git_executable after detection: ", git_executable)

	# Connect to folder opened signal
	GlobalSignals.folder_opened.connect(_on_folder_opened)
	GlobalSignals.file_saved.connect(_on_file_saved)
	GlobalSignals.file_changed.connect(_on_file_changed)

### Configuration

func _load_git_config() -> void:
	print("GitManager: Loading git config from ", CONFIG_FILE)
	var config = ConfigFile.new()
	if config.load(CONFIG_FILE) == OK:
		git_executable = config.get_value("git", "executable", "")
		print("GitManager: Loaded git_executable: ", git_executable)
	else:
		print("GitManager: Config file not found or error loading")

func _save_git_config() -> void:
	print("GitManager: Saving git config, executable: ", git_executable)
	var config = ConfigFile.new()
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
	print("GitManager: Verifying git executable at: ", path)
	var output = []
	var result = OS.execute(path, ['--version'], output)
	print("GitManager: Verify result: ", result, " output: ", output)
	return result == 0

func _detect_git_executable() -> bool:
	print("GitManager: Detecting git executable")
	var output = []
	var result: int
	if OS.get_name() == "Windows":
		result = OS.execute('where', ['git'], output)
	else:
		result = OS.execute('which', ['git'], output)
	print("GitManager: Command result: ", result, " output: ", output)
	if result == 0 and output.size() > 0:
		git_executable = output[0].strip_edges()
		print("GitManager: Found git at: ", git_executable)
		_save_git_config()
		return true
	print("GitManager: Git not found")
	git_executable = ""
	return false

### Repository Detection

func is_git_repo(path: String) -> bool:
	# Check if the path or any parent contains a .git directory
	return find_git_root(path) != ""

func find_git_root(path: String) -> String:
	var current = path.get_base_dir()
	while current != "":
		if DirAccess.dir_exists_absolute(current.path_join(".git")):
			return current
		current = current.get_base_dir()
		if current in ["/", ":/", ":\\"]:
			break
	return ""

func get_git_root() -> String:
	return git_root

### Git Command Execution

func _execute_git_command(args: Array, cwd: String = "") -> Array:
	print("GitManager: Executing git command: ", args, " in ", cwd)
	if git_executable == "":
		print("GitManager: ERROR - Git executable not configured")
		return ["", "Git executable not configured"]

	var full_args = args.duplicate()
	if cwd != "":
		full_args.insert(0, cwd)
		full_args.insert(0, '-C')

	var output = []
	var exit_code = OS.execute(git_executable, full_args, output)
	print("GitManager: Command exit code: ", exit_code, " output: ", output)

	if exit_code != 0 and output.size() == 0:
		return ["", "Command failed with exit code: %d" % exit_code]
	elif output.size() > 0:
		return [output[0], ""]
	else:
		return ["", ""]

func _execute_git_command_simple(args: Array, cwd: String = "") -> bool:
	return _execute_git_command(args, cwd)[1] == ""

### Core Git Operations

func init_git_repo(path: String) -> bool:
	if git_executable == "":
		GlobalSignals.git_operation_completed.emit("init", false, "Git executable not found")
		return false

	GlobalSignals.git_operation_started.emit("init")

	if is_git_repo(path):
		git_root = find_git_root(path)
		is_git_repo_cached = true
		GlobalSignals.git_operation_completed.emit("init", true, "Already a git repository")
		GlobalSignals.git_repo_changed.emit(true)
		return true

	if not _execute_git_command_simple(["init"], path):
		GlobalSignals.git_operation_completed.emit("init", false, "Failed to initialize git repo")
		return false

	git_root = path
	is_git_repo_cached = true
	ensure_snorfeld_in_gitignore()
	GlobalSignals.git_operation_completed.emit("init", true, "Git repository initialized")
	GlobalSignals.git_repo_changed.emit(true)
	return true

func get_status(base_path: String = "") -> Dictionary:
	print("GitManager: get_status() called with base_path: ", base_path)
	if git_executable == "":
		print("GitManager: ERROR - Git not found")
		return {"error": "Git not found"}

	var repo_path = base_path if base_path else git_root
	print("GitManager: repo_path: ", repo_path)
	if not repo_path:
		print("GitManager: ERROR - No git repository path")
		return {"error": "No git repository"}

	var output = _execute_git_command(["status", "--porcelain", "-u"], repo_path)
	print("GitManager: status command output: ", output)
	if output[0] == "":
		print("GitManager: ERROR - ", output[1])
		return {"error": output[1]}

	var status = {
		"files": [],  # Array of {path, change_type, staged}
		"counts": {"modified": 0, "staged": 0, "untracked": 0, "deleted": 0}
	}

	for line in output[0].split("\n"):
		if line.length() < 3:
			continue
		var staged_char = line[0]
		var unstaged_char = line[1]
		var file_path = line.substr(3)

		var change_type: String
		# Untracked files (?? ) are never staged
		var is_staged: bool = staged_char != " " and not (staged_char == "?" and unstaged_char == "?")

		if " -> " in file_path:
			file_path = file_path.split(" -> ")[1]
			change_type = "renamed"
		elif staged_char == "?" and unstaged_char == "?":
			change_type = "untracked"
		elif staged_char == "D" or unstaged_char == "D":
			change_type = "deleted"
		elif staged_char == "U" or unstaged_char == "U":
			change_type = "conflicted"
		elif unstaged_char == "M" or (unstaged_char == " " and staged_char == "M"):
			change_type = "modified"
		elif unstaged_char == "A" or (unstaged_char == " " and staged_char == "A"):
			change_type = "staged"  # New file added to git
		else:
			change_type = "modified"  # Default fallback

		status["files"].append({"path": file_path, "change_type": change_type, "staged": is_staged})
		status["counts"][change_type] += 1
		if is_staged:
			status["counts"]["staged"] += 1

	var branch_output = _execute_git_command(["branch", "--show-current"], repo_path)
	status["branch"] = branch_output[0].strip_edges() if branch_output[0] else "unknown"
	status["is_clean"] = status["files"].size() == 0
	return status

func get_file_status(file_path: String) -> String:
	if file_status_cache.has(file_path):
		return file_status_cache[file_path]

	if not git_root:
		return "not_git"

	var status = get_status()
	if status.has("error"):
		return "error"

	for file_info in status["files"]:
		if file_info["path"] == file_path:
			file_status_cache[file_path] = file_info["change_type"]
			return file_info["change_type"]

	file_status_cache[file_path] = "clean"
	return "clean"

func refresh_status(base_path: String = "") -> void:
	print("GitManager: refresh_status() called with base_path: ", base_path)

	var repo_path = base_path if base_path else git_root
	print("GitManager: refresh_status() - repo_path: ", repo_path)
	if not repo_path:
		print("GitManager: refresh_status() - no repo_path, returning")
		return

	var status = get_status(repo_path)
	print("GitManager: refresh_status() - status result: ", status)
	if not status.has("error"):
		print("GitManager: Emitting git_status_updated with: ", status)
		GlobalSignals.git_status_updated.emit(status)
		file_status_cache.clear()
		for file_info in status["files"]:
			file_status_cache[file_info["path"]] = file_info["change_type"]
			GlobalSignals.file_status_changed.emit(file_info["path"], file_info["change_type"])

### Diff Operations

func get_diff(file_path: String, staged: bool = false) -> String:
	if not git_executable or not git_root:
		return ""
	var args = ["diff"]
	if staged:
		args.append("--cached")
	args += ["--", file_path]
	return _execute_git_command(args, git_root)[0]

func get_diff_head(file_path: String) -> String:
	if not git_executable or not git_root:
		return ""
	return _execute_git_command(["diff", "HEAD", "--", file_path], git_root)[0]

func get_file_content_from_git(file_path: String) -> String:
	if not git_executable or not git_root:
		return ""
	var relative_path = _make_path_relative(file_path)
	var result = _execute_git_command(["show", "HEAD:" + relative_path], git_root)
	if result[1] == "":
		return result[0]
	return ""

### Staging Operations

func stage_file(file_path: String) -> bool:
	if not git_executable or not git_root:
		GlobalSignals.git_operation_completed.emit("stage", false, "Not a git repository")
		return false

	GlobalSignals.git_operation_started.emit("stage")
	var relative_path = _make_path_relative(file_path)
	if not _execute_git_command_simple(["add", relative_path], git_root):
		GlobalSignals.git_operation_completed.emit("stage", false, "Failed to stage file")
		return false

	file_status_cache.erase(file_path)
	refresh_status()
	GlobalSignals.git_operation_completed.emit("stage", true, "File staged")
	return true

func stage_all() -> bool:
	if not git_executable or not git_root:
		GlobalSignals.git_operation_completed.emit("stage_all", false, "Not a git repository")
		return false

	GlobalSignals.git_operation_started.emit("stage_all")
	if not _execute_git_command_simple(["add", "-A"], git_root):
		GlobalSignals.git_operation_completed.emit("stage_all", false, "Failed to stage all files")
		return false

	file_status_cache.clear()
	refresh_status()
	GlobalSignals.git_operation_completed.emit("stage_all", true, "All files staged")
	return true

func unstage_file(file_path: String) -> bool:
	if not git_executable or not git_root:
		GlobalSignals.git_operation_completed.emit("unstage", false, "Not a git repository")
		return false

	GlobalSignals.git_operation_started.emit("unstage")
	var relative_path = _make_path_relative(file_path)
	var success = (_execute_git_command_simple(["reset", "HEAD", "--", relative_path], git_root) or
		_execute_git_command_simple(["restore", "--staged", "--", relative_path], git_root))

	if not success:
		GlobalSignals.git_operation_completed.emit("unstage", false, "Failed to unstage file")
		return false

	file_status_cache.erase(file_path)
	refresh_status()
	GlobalSignals.git_operation_completed.emit("unstage", true, "File unstaged")
	return true

### Commit Operations

func commit(message: String) -> bool:
	if not git_executable or not git_root:
		GlobalSignals.git_operation_completed.emit("commit", false, "Not a git repository")
		return false
	if message == "":
		GlobalSignals.git_operation_completed.emit("commit", false, "Empty commit message")
		return false

	GlobalSignals.git_operation_started.emit("commit")
	if not _execute_git_command_simple(["commit", "-m", message], git_root):
		GlobalSignals.git_operation_completed.emit("commit", false, "Failed to commit")
		return false

	file_status_cache.clear()
	refresh_status()
	GlobalSignals.git_operation_completed.emit("commit", true, "Commit successful")
	return true

### Push/Pull/Fetch Operations

func push(remote: String = "origin", branch: String = "") -> bool:
	if not git_executable or not git_root:
		GlobalSignals.git_operation_completed.emit("push", false, "Not a git repository")
		return false

	GlobalSignals.git_operation_started.emit("push")
	var args = ["push", remote]
	if branch:
		args.append(branch)
	if not _execute_git_command_simple(args, git_root):
		GlobalSignals.git_operation_completed.emit("push", false, "Failed to push")
		return false

	GlobalSignals.git_operation_completed.emit("push", true, "Push successful")
	return true

func pull(remote: String = "origin", branch: String = "") -> bool:
	if not git_executable or not git_root:
		GlobalSignals.git_operation_completed.emit("pull", false, "Not a git repository")
		return false

	GlobalSignals.git_operation_started.emit("pull")
	var args = ["pull", remote]
	if branch:
		args.append(branch)
	if not _execute_git_command_simple(args, git_root):
		GlobalSignals.git_operation_completed.emit("pull", false, "Failed to pull")
		return false

	file_status_cache.clear()
	refresh_status()
	GlobalSignals.git_operation_completed.emit("pull", true, "Pull successful")
	return true

func fetch(remote: String = "origin") -> bool:
	if not git_executable or not git_root:
		GlobalSignals.git_operation_completed.emit("fetch", false, "Not a git repository")
		return false

	GlobalSignals.git_operation_started.emit("fetch")
	if not _execute_git_command_simple(["fetch", remote], git_root):
		GlobalSignals.git_operation_completed.emit("fetch", false, "Failed to fetch")
		return false

	GlobalSignals.git_operation_completed.emit("fetch", true, "Fetch successful")
	return true

### .gitignore Management

func add_to_gitignore(pattern: String) -> bool:
	if not git_root:
		return false

	var gitignore_path = git_root.path_join(".gitignore")
	var content = FileAccess.get_file_as_string(gitignore_path) if FileAccess.file_exists(gitignore_path) else ""

	if pattern in content:
		return true

	content += "\n%s\n" % pattern
	var file = FileAccess.open(gitignore_path, FileAccess.WRITE)
	if file:
		file.store_string(content)
		file.close()
		return true
	return false

func ensure_snorfeld_in_gitignore() -> bool:
	return add_to_gitignore(".snorfeld")

### Helper Methods

func _make_path_relative(file_path: String) -> String:
	if not git_root:
		return file_path

	var normalized_root = git_root.replace("\\", "/").replace("//", "/")
	var normalized_path = file_path.replace("\\", "/").replace("//", "/")

	if normalized_path.begins_with(normalized_root):
		var relative = normalized_path.substr(normalized_root.length())
		return relative.trim_prefix("/")

	return file_path

func get_absolute_path(relative_path: String) -> String:
	if not git_root:
		return relative_path
	var normalized_root = git_root.replace("\\", "/").replace("//", "/")
	var normalized_relative = relative_path.replace("\\", "/").replace("//", "/")
	return normalized_root.path_join(normalized_relative)

### Event Handlers

func _on_folder_opened(path: String):
	print("GitManager: _on_folder_opened: ", path)
	git_root = find_git_root(path)
	print("GitManager: git_root found: ", git_root)
	is_git_repo_cached = git_root != ""
	GlobalSignals.git_repo_changed.emit(is_git_repo_cached)
	if is_git_repo_cached:
		print("GitManager: Git repo detected, ensuring .snorfeld in .gitignore")
		ensure_snorfeld_in_gitignore()
		print("GitManager: Git repo detected, refreshing status")
		refresh_status(path)
	else:
		print("GitManager: Not a git repository")

func _on_file_saved(path: String):
	if is_git_repo_cached:
		file_status_cache.erase(path)
		call_deferred("refresh_status")

func _on_file_changed(path: String, _content: String):
	if is_git_repo_cached:
		file_status_cache.erase(path)
		call_deferred("refresh_status")
