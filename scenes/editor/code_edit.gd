extends CodeEdit

# gdlint:ignore-file:file-length

var current_file_path: String = ""
var last_text: String = ""
var last_cursor_line: int = -1
var font_size: int
var default_font_size : int

func _ready():
	# Get font size from theme, fallback to 16

	default_font_size = get_theme_font_size("font_size", "CodeEdit")
	font_size = default_font_size
	add_theme_font_size_override("font_size", font_size)

	# Set width based on editor line length setting
	call_deferred('_set_editor_width')

	var highlighter: RefCounted = load("res://scripts/utilities/syntax_highlighter.gd").new()
	syntax_highlighter = highlighter

	EventBus.file_selected.connect(_on_file_selected)
	CommandBus.apply_diff_patch.connect(_on_apply_diff_patch_command)
	CommandBus.save_all_files.connect(_on_save_all_files)
	EventBus.show_git_diff.connect(_on_show_git_diff)
	CommandBus.navigate_to_line.connect(_on_navigate_to_line_command)
	EventBus.content_changed.connect(_on_content_changed)
	EventBus.editor_resized.connect(_on_editor_resized)

	caret_changed.connect(_on_cursor_changed)
	text_changed.connect(_on_text_changed)

func _on_save_all_files():
	# Emit final editor_content_changed with current content before shutdown
	if current_file_path != "" and FileUtils.file_exists(current_file_path):
		EventBus.editor_content_changed.emit(current_file_path, get_text())

func _on_content_changed():
	# BookService detected a content change - reload current file if it exists
	if current_file_path != "" and FileUtils.file_exists(current_file_path):
		var cursor_line: int = get_caret_line()
		var cursor_column: int = get_caret_column()
		var scroll_pos: float = get_v_scroll_bar().value

		# Reload the file
		var content: String = FileUtils.read_file(current_file_path)
		if content != last_text:
			last_cursor_line = -1  # Force paragraph re-analysis
			call_deferred("_reload_and_restore", content, cursor_line, cursor_column, scroll_pos)

func _reload_and_restore(content: String, cursor_line: int, cursor_column: int, scroll_pos: float):
	set_text(content)
	last_text = content
	last_cursor_line = -1  # Force paragraph re-analysis
	if cursor_line >= 0:
		var line_count: int = get_line_count()
		cursor_line = clamp(cursor_line, 0, line_count - 1)
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
		var content: String = FileUtils.read_file(file_path)
		if content != "":
			last_text = content
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
	# Save current file before switching - emit editor_content_changed with current content
	if current_file_path != "" and current_file_path != path:
		var current_content: String = get_text()
		EventBus.editor_content_changed.emit(current_file_path, current_content)
		CommandBus.save_file.emit(current_file_path)

	current_file_path = path
	last_text = ""
	last_cursor_line = -1  # Force paragraph re-analysis
	var content: String = FileUtils.read_file(path)
	if content != "":
		set_text(content)
		last_text = content

	# Make sure panel is visible
	visible = true

func _on_cursor_changed():
	var cursor_line: int = get_caret_line()
	if cursor_line < 0:
		return

	# Only emit when line changes, not column
	if cursor_line != last_cursor_line:
		last_cursor_line = cursor_line
		EventBus.paragraph_selected.emit(current_file_path, cursor_line + 1)

func _on_text_changed():
	# Emit editor_content_changed signal when text changes
	var current_text: String = get_text()
	if current_text != last_text:
		last_text = current_text
		EventBus.editor_content_changed.emit(current_file_path, current_text)



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
	# Emit editor_content_changed signal since text was modified
	EventBus.editor_content_changed.emit(current_file_path, get_text())

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.pressed:
			var is_meta_pressed: bool = key_event.meta_pressed
			var is_ctrl_pressed: bool = key_event.ctrl_pressed
			# Use Meta (Cmd) on macOS, Ctrl on other platforms
			var modifier_pressed: bool = is_meta_pressed or is_ctrl_pressed

			if modifier_pressed:
				if key_event.keycode == KEY_EQUAL or key_event.keycode == KEY_KP_ADD:
					zoom_in()
					get_viewport().set_input_as_handled()
				elif key_event.keycode == KEY_MINUS or key_event.keycode == KEY_KP_SUBTRACT:
					zoom_out()
					get_viewport().set_input_as_handled()
				elif key_event.keycode == KEY_0 or key_event.keycode == KEY_KP_0:
					font_size = default_font_size
					add_theme_font_size_override("font_size", font_size)
					_set_editor_width()
					get_viewport().set_input_as_handled()

func zoom_in() -> void:
	font_size += 2
	add_theme_font_size_override("font_size", font_size)
	_set_editor_width()

func zoom_out() -> void:
	font_size = max(font_size - 2, 6)
	add_theme_font_size_override("font_size", font_size)
	_set_editor_width()

func _set_editor_width() -> void:
	var line_length: int = AppConfig.get_editor_line_length()
	var line_width: float = 0.5 * font_size * line_length
	var margins : int = 50;
	custom_minimum_size.x = min(line_width, get_parent().get_parent_area_size().x - margins)

func _on_editor_resized() -> void:
	call_deferred("_set_editor_width")
