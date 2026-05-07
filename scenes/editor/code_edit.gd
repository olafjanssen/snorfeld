extends CodeEdit

# gdlint:ignore-file:file-length

# Constants
const FILE_CHECK_INTERVAL: float = 5.0

var current_file_path: String = ""
var last_text: String = ""

var last_modified_time: float = 0.0
var file_check_timer: Timer

func _ready():
	var highlighter: RefCounted = load("res://scripts/utilities/syntax_highlighter.gd").new()
	syntax_highlighter = highlighter

	EventBus.file_selected.connect(_on_file_selected)
	CommandBus.apply_diff_patch.connect(_on_apply_diff_patch_command)
	CommandBus.save_all_files.connect(_on_save_all_files)
	EventBus.show_git_diff.connect(_on_show_git_diff)
	CommandBus.navigate_to_line.connect(_on_navigate_to_line_command)
	EventBus.content_changed.connect(_on_book_content_changed)

	caret_changed.connect(_on_cursor_changed)
	text_changed.connect(_on_text_changed)

	# Setup timer to check for external file changes
	file_check_timer = Timer.new()
	file_check_timer.timeout.connect(_on_file_check_timeout)
	file_check_timer.wait_time = FILE_CHECK_INTERVAL
	add_child(file_check_timer)
	file_check_timer.start()

func _exit_tree():
	# Clean up timers
	if file_check_timer:
		file_check_timer.queue_free()
		file_check_timer = null
	# Note: syntax_highlighter is a RefCounted object and is managed automatically

func _on_save_all_files():
	# Emit final file_changed with current content before shutdown
	if current_file_path != "" and FileUtils.file_exists(current_file_path):
		EventBus.file_changed.emit(current_file_path, get_text())

func _on_file_check_timeout():
	if current_file_path == "":
		return

	if FileUtils.file_exists(current_file_path):
		var current_mod_time: float = FileUtils.get_modified_time(current_file_path)
		if current_mod_time > last_modified_time:
			# File was modified externally - save cursor position
			var cursor_line: int = get_caret_line()
			var cursor_column: int = get_caret_column()
			var scroll_pos: float = get_v_scroll_bar().value

			last_modified_time = current_mod_time

			# Reload the file
			var content: String = FileUtils.get_file_as_string(current_file_path)
			set_text(content)
			last_text = content

			# Restore cursor position
			if cursor_line >= 0:
				set_caret_line(cursor_line)
				var line_length: int = get_line(cursor_line).length()
				set_caret_column(min(cursor_column, line_length))
			get_v_scroll_bar().value = scroll_pos

func _on_show_git_diff(_file_path: String, _diff: String):
	visible = false

func _on_navigate_to_line_command(file_path: String, line_number: int):
	if current_file_path == file_path:
		var line_count: int = get_line_count()
		var target_line: int = clamp(line_number - 1, 0, line_count - 1)
		call_deferred("_set_caret_and_center", target_line)
		grab_focus()
	else:
		current_file_path = file_path
		last_text = ""
		var content: String = FileUtils.get_file_as_string(file_path)
		if content != "":
			last_text = content
			last_modified_time = FileUtils.get_modified_time(file_path)
			set_text(content)
			var line_count: int = get_line_count()
			var target_line: int = clamp(line_number - 1, 0, line_count - 1)
			call_deferred("_set_caret_and_center", target_line)
			grab_focus()
		visible = true

func _set_caret_and_center(line_number: int):
	set_caret_column(0)
	set_caret_line(line_number)
	center_viewport_to_caret()

func _on_file_selected(path: String):
	# Save current file before switching - emit file_changed with current content
	if current_file_path != "" and current_file_path != path:
		var current_content: String = get_text()
		EventBus.file_changed.emit(current_file_path, current_content)
		CommandBus.save_file.emit(current_file_path)

	current_file_path = path
	last_text = ""
	var content: String = FileUtils.get_file_as_string(path)
	if content != "":
		set_text(content)
		last_text = content
		last_modified_time = FileUtils.get_modified_time(path)

	# Make sure panel is visible
	visible = true

func _on_cursor_changed():
	var cursor_line: int = get_caret_line()
	if cursor_line < 0:
		return

	# Emit signal with file_path and line number (1-based)
	# Consumers will use BookService to get paragraph data
	EventBus.paragraph_selected.emit(current_file_path, cursor_line + 1)

func _on_book_content_changed():
	# BookService content changed - refresh our view if we have a file loaded
	if current_file_path != "":
		# Force a cursor change to update paragraph selection
		_on_cursor_changed()


func _on_text_changed():
	# Emit file_changed signal when text changes
	var current_text: String = get_text()
	if current_text != last_text:
		last_text = current_text
		EventBus.file_changed.emit(current_file_path, current_text)



# gdlint:ignore-function:too-many-params,long-function,long-line
func _on_apply_diff_patch_command(
	file_path: String,
	line_number: int,
	operation: String,
	word_index: int,
	new_text: String
):
	if current_file_path != file_path:
		return

	var saved_state: Dictionary = _save_editor_state()
	var lines: Array = get_text().split("\n")
	var cursor_line: int = line_number - 1

	if not _validate_patch_context(cursor_line, lines, file_path, line_number):
		return

	var current_paragraph: String = lines[cursor_line]
	var modified_paragraph: String = _apply_patch_operation(
		current_paragraph,
		operation,
		word_index,
		new_text
	)

	if modified_paragraph != current_paragraph:
		_restore_editor_with_modified_line(lines, cursor_line, modified_paragraph, saved_state)

## Save current editor state (cursor position and scroll)
func _save_editor_state() -> Dictionary:
	return {
		"cursor_column": get_caret_column(),
		"scroll_pos": get_v_scroll_bar().value
	}

## Validate patch context
func _validate_patch_context(cursor_line: int, lines: Array, file_path: String, line_number: int) -> bool:
	if cursor_line < 0 or cursor_line >= lines.size():
		return false
	var para_data: Dictionary = BookService.get_paragraph_at_line(file_path, line_number)
	return not para_data.is_empty()

## Apply patch operation to a paragraph
func _apply_patch_operation(current_paragraph: String, operation: String, word_index: int, new_text: String) -> String:
	var words: Array = current_paragraph.split(" ")

	if operation == "delete":
		return _apply_delete_operation(words, word_index, new_text)
	elif operation == "insert":
		return _apply_insert_operation(words, word_index, new_text)
	elif operation == "change":
		return _apply_change_operation(words, word_index, new_text)
	return current_paragraph

## Apply delete operation
func _apply_delete_operation(words: Array, word_index: int, new_text: String) -> String:
	var delete_words: Array = new_text.split(" ")
	if word_index < 0 or word_index + delete_words.size() > words.size():
		return " ".join(words)

	# Verify the words match what we expect to delete
	for k: int in range(delete_words.size()):
		if words[word_index + k] != delete_words[k]:
			return " ".join(words)

	# Remove multiple words starting at word_index
	for _k: int in range(delete_words.size()):
		words.remove_at(word_index)
	return " ".join(words)

## Apply insert operation
func _apply_insert_operation(words: Array, word_index: int, new_text: String) -> String:
	if word_index >= 0 and word_index <= words.size():
		words.insert(word_index, new_text)
	return " ".join(words)

## Apply change operation
func _apply_change_operation(words: Array, word_index: int, new_text: String) -> String:
	var new_words_list: Array = new_text.split(" ")
	if word_index >= 0 and word_index + new_words_list.size() <= words.size():
		for k: int in range(new_words_list.size()):
			words[word_index + k] = new_words_list[k]
	return " ".join(words)

## Restore editor with modified line
func _restore_editor_with_modified_line(
	lines: Array,
	cursor_line: int,
	modified_paragraph: String,
	saved_state: Dictionary
):
	lines[cursor_line] = modified_paragraph
	var new_text_full: String = "\n".join(lines)

	set_text(new_text_full)

	# Restore scroll position
	get_v_scroll_bar().value = saved_state["scroll_pos"]

	# Restore cursor to the same line
	set_caret_line(cursor_line)
	var line_length: int = lines[cursor_line].length()
	set_caret_column(min(saved_state["cursor_column"], line_length))

	# Re-trigger paragraph selection to update diff display
	EventBus.paragraph_selected.emit(current_file_path, cursor_line + 1)
	# Emit file_changed signal since text was modified
	EventBus.file_changed.emit(current_file_path, get_text())
