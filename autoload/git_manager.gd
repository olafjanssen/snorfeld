extends Node
## GitManager - Core git operations using OS.execute()
## Provides git integration for the Snorfeld editor

# Signals
signal git_status_updated(status: Dictionary)
signal git_diff_available(file_path: String, diff: String)
signal git_operation_started(operation: String)
signal git_operation_completed(operation: String, success: bool, message: String)
signal git_repo_changed(is_git_repo: bool)
signal file_status_changed(file_path: String, status: String)

# Git status cache
var git_root: String = ""
var is_git_repo_cached: bool = false
var file_status_cache: Dictionary = {}
var last_status_refresh: float = 0.0
const STATUS_REFRESH_COOLDOWN: float = 1.0

# Git executable path - default to standard locations
var git_executable: String = ""

# Config file for storing user preferences
const CONFIG_FILE: String = "user://git_config.cfg"

func _ready():
	_load_git_config()
	if git_executable == "":
		# Set platform-specific defaults
		if OS.has_feature("Mac OS X"):
			git_executable = "/usr/bin/git"
		elif OS.has_feature("Unix"):
			git_executable = "git"
		elif OS.has_feature("Windows"):
			git_executable = "git.exe"

		# Verify the default works
		if git_executable != "" and not _verify_git_executable(git_executable):
			git_executable = ""
			_detect_git_executable()


## Configuration

func _load_git_config() -> void:
	var config = ConfigFile.new()
	if config.load(CONFIG_FILE) == OK:
		git_executable = config.get_value("git", "executable", "")

func _save_git_config() -> void:
	var config = ConfigFile.new()
	config.set_value("git", "executable", git_executable)
	config.save(CONFIG_FILE)

func set_git_executable(path: String) -> void:
	git_executable = path
	_save_git_config()

func _verify_git_executable(path: String) -> bool:
	var exit_code = OS.execute(path + " --version", [])
	return exit_code == 0


## Git Executable Detection

func _detect_git_executable() -> bool:
	# Try common paths for each platform
	var paths = []

	if OS.has_feature("Mac OS X"):
		paths = ["/usr/bin/git"]
	elif OS.has_feature("Unix"):
		paths = ["git", "/usr/bin/git", "/usr/local/bin/git"]
	elif OS.has_feature("Windows"):
		paths = [
			"git.exe",
			"C:/Program Files/Git/bin/git.exe",
			"C:/Program Files (x86)/Git/bin/git.exe"
		]

	for path in paths:
		if _verify_git_executable(path):
			git_executable = path
			print("Git found at: ", path)
			_save_git_config()
			return true

	print("Warning: Git not found. Set path in Settings.")
	git_executable = ""
	return false


func _execute_git_command_simple(args: Array, cwd: String = "", custom_git_path: String = "") -> bool:
	var executable = custom_git_path if custom_git_path != "" else git_executable
	var command = executable + " " + " ".join(args)
	var exit_code = OS.execute(command, [])
	return exit_code == 0


## Repository Detection

func is_git_repo(path: String) -> bool:
	if git_executable == "":
		# Even without git executable, we can check for .git directory
		var git_dir = path.get_base_dir().path_join(".git")
		return DirAccess.dir_exists_absolute(git_dir)

	# Check if .git directory exists
	var git_dir = path.get_base_dir().path_join(".git")
	if DirAccess.dir_exists_absolute(git_dir):
		return true

	return false

func find_git_root(path: String) -> String:
	# Walk up directories looking for .git (works even without git executable)
	var current = path.get_base_dir()
	while current != "":
		if DirAccess.dir_exists_absolute(current.path_join(".git")):
			return current
		current = current.get_base_dir()
		if current == "/" or current.ends_with(":/") or current.ends_with(":\\"):
			break

	return ""

func get_git_root() -> String:
	return git_root


## Repository Initialization

func init_git_repo(path: String) -> bool:
	if git_executable == "":
		git_operation_completed.emit("init", false, "Git executable not found")
		return false

	git_operation_started.emit("init")

	if is_git_repo(path):
		git_root = find_git_root(path)
		is_git_repo_cached = true
		git_operation_completed.emit("init", true, "Already a git repository")
		git_repo_changed.emit(true)
		return true

	if not _execute_git_command_simple(["init"], path):
		git_operation_completed.emit("init", false, "Failed to initialize git repo")
		return false

	git_root = path
	is_git_repo_cached = true
	ensure_snorfeld_in_gitignore()

	git_operation_completed.emit("init", true, "Git repository initialized")
	git_repo_changed.emit(true)
	return true


## Status Operations

func get_status(base_path: String = "") -> Dictionary:
	if git_executable == "":
		return {"error": "Git not found"}

	var repo_path = base_path if base_path != "" else git_root
	if repo_path == "":
		return {"error": "No git repository"}

	# Run git status and parse output
	var output = _execute_git_command_with_output(["status", "--porcelain", "-u"], repo_path)

	if output[0] == "":
		return {"error": output[1]}

	var status: Dictionary = {
		"modified": [],
		"staged": [],
		"untracked": [],
		"deleted": [],
		"renamed": [],
		"conflicted": []
	}

	var lines = output[0].split("\n")
	for line in lines:
		if line == "":
			continue

		# Porcelain format: XY path (X=staged, Y=unstaged)
		if line.length() < 3:
			continue

		var staged_char = line[0]
		var unstaged_char = line[1]
		var rest = line.substr(3)

		var is_rename = " -> " in rest

		if is_rename:
			var parts = rest.split(" -> ")
			if parts.size() >= 2:
				status["renamed"].append(parts[1])
		elif staged_char == "?" and unstaged_char == "?":
			status["untracked"].append(rest)
		elif staged_char == "D" or unstaged_char == "D":
			status["deleted"].append(rest)
		elif staged_char == "U" or unstaged_char == "U":
			status["conflicted"].append(rest)
		elif staged_char != " " or unstaged_char != " ":
			if staged_char != " ":
				status["staged"].append(rest)
			if unstaged_char != " ":
				status["modified"].append(rest)

	# Get branch
	var branch_output = _execute_git_command_with_output(["branch", "--show-current"], repo_path)
	if branch_output[0] != "":
		status["branch"] = branch_output[0].strip_edges()
	else:
		status["branch"] = "unknown"

	status["is_clean"] = (status["modified"].size() == 0 and
			status["staged"].size() == 0 and
			status["untracked"].size() == 0 and
			status["deleted"].size() == 0)

	return status

func get_file_status(file_path: String) -> String:
	if file_status_cache.has(file_path):
		return file_status_cache[file_path]

	if git_root == "":
		return "not_git"

	var status = get_status()
	if status.has("error"):
		return "error"

	if file_path in status["untracked"]:
		file_status_cache[file_path] = "untracked"
		return "untracked"
	if file_path in status["deleted"]:
		file_status_cache[file_path] = "deleted"
		return "deleted"
	if file_path in status["staged"]:
		file_status_cache[file_path] = "staged"
		return "staged"
	if file_path in status["modified"]:
		file_status_cache[file_path] = "modified"
		return "modified"

	file_status_cache[file_path] = "clean"
	return "clean"

func refresh_status(base_path: String = "") -> void:
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_status_refresh < STATUS_REFRESH_COOLDOWN:
		return

	last_status_refresh = current_time

	var repo_path = base_path if base_path != "" else git_root
	if repo_path == "":
		return

	var status = get_status(repo_path)
	if not status.has("error"):
		git_status_updated.emit(status)
		file_status_cache.clear()
		for file_path in status["modified"]:
			file_status_cache[file_path] = "modified"
			file_status_changed.emit(file_path, "modified")
		for file_path in status["staged"]:
			file_status_cache[file_path] = "staged"
			file_status_changed.emit(file_path, "staged")
		for file_path in status["untracked"]:
			file_status_cache[file_path] = "untracked"
			file_status_changed.emit(file_path, "untracked")

func _execute_git_command_with_output(args: Array, cwd: String) -> Array:
	if git_executable == "":
		return ["", "Git executable not configured"]

	# Create a temp file for output
	var temp_file = OS.get_temp_dir().path_join("godot_git_output_" + str(Time.get_unix_time_from_system()) + ".txt")

	# Build the command with output redirection
	var command = git_executable + " " + " ".join(args)
	if cwd != "":
		command = "cd \"" + cwd + "\" && " + command
	command = command + " > \"" + temp_file + "\" 2> \"" + temp_file + "\""

	var exit_code = OS.execute(command, [])

	var output = ["", ""]
	if FileAccess.file_exists(temp_file):
		var file = FileAccess.open(temp_file, FileAccess.READ)
		if file:
			output[0] = file.get_as_text()
			file.close()
		# Clean up temp file
		var dir = DirAccess.open(OS.get_temp_dir())
		if dir:
			dir.remove(temp_file)
			dir.close()

	if exit_code != 0 and output[0] == "":
		output[1] = "Command failed with exit code: " + str(exit_code)

	return output


## Diff Operations

func get_diff(file_path: String, staged: bool = false) -> String:
	if git_executable == "" or git_root == "":
		return ""

	var args = ["diff"]
	if staged:
		args.append("--cached")
	args.append("--")
	args.append(file_path)

	var result = _execute_git_command_with_output(args, git_root)
	if result[0] != "":
		return result[0]
	else:
		return ""

func get_diff_head(file_path: String) -> String:
	if git_executable == "" or git_root == "":
		return ""

	var result = _execute_git_command_with_output(["diff", "HEAD", "--", file_path], git_root)
	if result[0] != "":
		return result[0]
	else:
		return ""


## Staging Operations

func stage_file(file_path: String) -> bool:
	if git_executable == "" or git_root == "":
		git_operation_completed.emit("stage", false, "Not a git repository")
		return false

	git_operation_started.emit("stage")

	var relative_path = _make_path_relative(file_path)
	if not _execute_git_command_simple(["add", relative_path], git_root):
		git_operation_completed.emit("stage", false, "Failed to stage file")
		return false

	file_status_cache.erase(file_path)
	refresh_status()
	git_operation_completed.emit("stage", true, "File staged")
	return true

func stage_all() -> bool:
	if git_executable == "" or git_root == "":
		git_operation_completed.emit("stage_all", false, "Not a git repository")
		return false

	git_operation_started.emit("stage_all")

	if not _execute_git_command_simple(["add", "-A"], git_root):
		git_operation_completed.emit("stage_all", false, "Failed to stage all files")
		return false

	file_status_cache.clear()
	refresh_status()
	git_operation_completed.emit("stage_all", true, "All files staged")
	return true

func unstage_file(file_path: String) -> bool:
	if git_executable == "" or git_root == "":
		git_operation_completed.emit("unstage", false, "Not a git repository")
		return false

	git_operation_started.emit("unstage")

	var relative_path = _make_path_relative(file_path)

	if not _execute_git_command_simple(["reset", "HEAD", "--", relative_path], git_root):
		if not _execute_git_command_simple(["restore", "--staged", "--", relative_path], git_root):
			git_operation_completed.emit("unstage", false, "Failed to unstage file")
			return false

	file_status_cache.erase(file_path)
	refresh_status()
	git_operation_completed.emit("unstage", true, "File unstaged")
	return true


## Commit Operations

func commit(message: String) -> bool:
	if git_executable == "" or git_root == "":
		git_operation_completed.emit("commit", false, "Not a git repository")
		return false

	if message == "":
		git_operation_completed.emit("commit", false, "Empty commit message")
		return false

	git_operation_started.emit("commit")

	if not _execute_git_command_simple(["commit", "-m", message], git_root):
		git_operation_completed.emit("commit", false, "Failed to commit")
		return false

	file_status_cache.clear()
	refresh_status()
	git_operation_completed.emit("commit", true, "Commit successful")
	return true


## Push/Pull/Fetch Operations

func push(remote: String = "origin", branch: String = "") -> bool:
	if git_executable == "" or git_root == "":
		git_operation_completed.emit("push", false, "Not a git repository")
		return false

	git_operation_started.emit("push")

	var args = ["push", remote]
	if branch != "":
		args.append(branch)

	if not _execute_git_command_simple(args, "", git_root):
		git_operation_completed.emit("push", false, "Failed to push")
		return false

	git_operation_completed.emit("push", true, "Push successful")
	return true

func pull(remote: String = "origin", branch: String = "") -> bool:
	if git_executable == "" or git_root == "":
		git_operation_completed.emit("pull", false, "Not a git repository")
		return false

	git_operation_started.emit("pull")

	var args = ["pull", remote]
	if branch != "":
		args.append(branch)

	if not _execute_git_command_simple(args, "", git_root):
		git_operation_completed.emit("pull", false, "Failed to pull")
		return false

	file_status_cache.clear()
	refresh_status()
	git_operation_completed.emit("pull", true, "Pull successful")
	return true

func fetch(remote: String = "origin") -> bool:
	if git_executable == "" or git_root == "":
		git_operation_completed.emit("fetch", false, "Not a git repository")
		return false

	git_operation_started.emit("fetch")

	if not _execute_git_command_simple(["fetch", remote], git_root):
		git_operation_completed.emit("fetch", false, "Failed to fetch")
		return false

	git_operation_completed.emit("fetch", true, "Fetch successful")
	return true


## .gitignore Management

func add_to_gitignore(pattern: String) -> bool:
	if git_root == "":
		return false

	var gitignore_path = git_root.path_join(".gitignore")

	if FileAccess.file_exists(gitignore_path):
		var content = FileAccess.get_file_as_string(gitignore_path)
		if pattern in content:
			return true
		content += "\n" + pattern + "\n"
		var file = FileAccess.open(gitignore_path, FileAccess.WRITE)
		if file:
			file.store_string(content)
			file.close()
			return true

	var file = FileAccess.open(gitignore_path, FileAccess.WRITE)
	if file:
		file.store_string(pattern + "\n")
		file.close()
		return true

	return false

func ensure_snorfeld_in_gitignore() -> bool:
	return add_to_gitignore(".snorfeld")


## Helper Methods

func _make_path_relative(file_path: String) -> String:
	if git_root == "":
		return file_path

	var normalized_root = git_root.replace("\\", "/").replace("//", "/")
	var normalized_path = file_path.replace("\\", "/").replace("//", "/")

	if normalized_path.begins_with(normalized_root):
		var relative = normalized_path.substr(normalized_root.length())
		if relative.begins_with("/"):
			relative = relative.substr(1)
		return relative

	return file_path


## Event Handlers

func _on_folder_opened(path: String):
	git_root = find_git_root(path)
	is_git_repo_cached = git_root != ""
	git_repo_changed.emit(is_git_repo_cached)

	if is_git_repo_cached:
		refresh_status(path)

func _on_file_saved(path: String):
	if is_git_repo_cached:
		file_status_cache.erase(path)
		call_deferred("refresh_status")

func _on_file_changed(path: String, content: String):
	if is_git_repo_cached:
		file_status_cache.erase(path)
