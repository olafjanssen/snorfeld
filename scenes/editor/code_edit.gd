extends CodeEdit

# gdlint:ignore-file:file-length

const MIN_FONT_SIZE : int = 6
const EDITOR_MARGIN : int = 50

var current_file_path: String = ""
var last_text: String = ""
var last_cursor_line: int = -1
var last_word_index: int = -1

var font_size: int
var default_font_size : int
var scrollContainer : ScrollContainer

func _ready():
	# Get font size from theme, fallback to 16
	default_font_size = get_theme_font_size("font_size", "CodeEdit")
	font_size = default_font_size
	add_theme_font_size_override("font_size", font_size)

	# Set width based on editor line length setting
	call_deferred('_set_editor_width')

	scrollContainer = get_parent_control()

	var highlighter: RefCounted = load("res://scripts/utilities/syntax_highlighter.gd").new()
	syntax_highlighter = highlighter

	EventBus.file_selected.connect(_on_file_selected)
	CommandBus.apply_diff_patch.connect(_on_apply_diff_patch_command)
	CommandBus.save_all_files.connect(_on_save_all_files)
	EventBus.show_git_diff.connect(_on_show_git_diff)
	CommandBus.navigate_to_line.connect(_on_navigate_to_line_command)
	EventBus.content_changed.connect(_on_content_changed)
	EventBus.editor_resized.connect(_on_editor_resized)

	caret_changed.connect(_on_caret_changed)
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
		if content != get_text():
			last_cursor_line = -1  # Force paragraph re-analysis
			set_text(content)
			last_text = content
			get_v_scroll_bar().value = scroll_pos
			if cursor_line >= 0:
				var line_count: int = get_line_count()
				cursor_line = clamp(cursor_line, 0, line_count - 1)
				set_caret_line(cursor_line)
				var line_length: int = get_line(cursor_line).length()
				set_caret_column(min(cursor_column, line_length))

func _on_show_git_diff(_file_path: String, _diff: String):
	visible = false

func _load_file(path: String) -> void:
	if current_file_path != "" and current_file_path != path:
		var current_content: String = get_text()
		EventBus.editor_content_changed.emit(current_file_path, current_content)
		CommandBus.save_file.emit(current_file_path)

	current_file_path = path
	last_text = ""
	last_cursor_line = -1
	var content: String = FileUtils.read_file(path)
	if content != "":
		last_text = content
		set_text(content)
		clear_undo_history()
		grab_focus()
	visible = true

func _on_navigate_to_line_command(file_path: String, line_number: int):
	if current_file_path == file_path:
		var target_line: int = clamp(line_number - 1, 0, get_line_count() - 1)
		call_deferred("_set_caret_and_center", target_line)
		grab_focus()
	else:
		_load_file(file_path)
		_on_navigate_to_line_command(file_path, line_number)

func _set_caret_and_center(line_number: int):
	set_caret_column(0)
	set_caret_line(line_number)
	center_viewport_to_caret()

func _on_file_selected(path: String):
	_load_file(path)

func _ensure_caret_in_center_view():
	var verticalPosition : float = get_caret_draw_pos().y
	var scrollPosition : int = max(0, int(verticalPosition - scrollContainer.size.y/2))
	scrollContainer.set_v_scroll(scrollPosition)

func _ensure_caret_in_view():
	var verticalPosition : float = get_caret_draw_pos().y
	if verticalPosition - font_size < scrollContainer.get_v_scroll():
		scrollContainer.set_v_scroll(int(verticalPosition - font_size))
	elif verticalPosition + font_size > scrollContainer.get_v_scroll() + scrollContainer.size.y:
		scrollContainer.set_v_scroll(int(verticalPosition - scrollContainer.size.y + font_size))

func _on_caret_changed():
	var cursor_line: int = get_caret_line()
	if cursor_line < 0:
		return

	_ensure_caret_in_view()

	# Only emit when line changes, not column
	if cursor_line != last_cursor_line:
		last_cursor_line = cursor_line
		EventBus.paragraph_selected.emit(current_file_path, cursor_line + 1)

	# Detect word under caret and emit word_selected if changed
	var current_word: String = _get_word_at_caret()
	if current_word.is_empty():
		return

	# Find word index in the line
	var line_text: String = get_line(cursor_line)
	# If caret is at the end of the line, we're probably writing and we don't emit word_selected
	if get_caret_column() == len(line_text):
		return

	line_text = line_text.strip_edges()
	var words_in_line: PackedStringArray = line_text.split(" ")
	var word_idx: int = 0
	var found: bool = false
	for i in range(words_in_line.size()):
		# Clean the word for comparison (remove punctuation)
		var cleaned: String = words_in_line[i].strip_edges()
		while cleaned.length() > 0 and _is_punctuation(cleaned.substr(cleaned.length() - 1, 1)):
			cleaned = cleaned.substr(0, cleaned.length() - 1)
		while cleaned.length() > 0 and _is_punctuation(cleaned.substr(0, 1)):
			cleaned = cleaned.substr(1)
		if cleaned == current_word:
			word_idx = i
			found = true
			break
	if found and word_idx != last_word_index:
		print(current_word, "  ", word_idx, "  ",last_word_index)
		last_word_index = word_idx
		EventBus.word_selected.emit(current_file_path, cursor_line + 1, word_idx, current_word)

func _is_punctuation(character: String) -> bool:
	var code: int = ord(character)
	# ASCII punctuation
	return (code >= 33 and code <= 47) or (code >= 58 and code <= 64) or (code >= 91 and code <= 96) or (code >= 123 and code <= 126)

func _get_word_at_caret() -> String:
	var cursor_line: int = get_caret_line()
	if cursor_line < 0:
		return ""

	var line_text: String = get_line(cursor_line)
	var cursor_col: int = get_caret_column()

	# Find the start of the word (first word boundary before caret)
	var word_start: int = cursor_col
	while word_start > 0:
		var prev_char: String = line_text.substr(word_start - 1, 1)
		if _is_word_boundary(prev_char):
			break
		word_start -= 1

	# Find the end of the word (first word boundary after cursor_col)
	var word_end: int = cursor_col
	while word_end < line_text.length():
		var char: String = line_text.substr(word_end, 1)
		if _is_word_boundary(char):
			break
		word_end += 1

	if word_end > word_start:
		return line_text.substr(word_start, word_end - word_start)
	return ""

func _is_word_boundary(char: String) -> bool:
	# Word boundaries: spaces, tabs, newlines, most punctuation
	# Apostrophes and hyphens are NOT boundaries (keep contractions and hyphenated words together)
	var code: int = ord(char)
	# Space characters (space, tab, newline, carriage return, non-breaking space)
	if code == 32 or code == 9 or code == 10 or code == 13 or code == 160:
		return true
	# ASCII punctuation - exclude apostrophe (39) and hyphen (45)
	if (code >= 33 and code <= 44) or code == 46 or code == 47:
		return true
	if (code >= 58 and code <= 64) or (code >= 91 and code <= 96) or (code >= 123 and code <= 126):
		return true
	# Common typographic punctuation (Unicode) - exclude smart apostrophes
	if code == 8211 or code == 8212 or code == 8220 or code == 8221:
		return true
	return false

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
	old_text: String,
	new_text: String
):
	if current_file_path != file_path:
		return

	var cursor_line: int = line_number - 1
	if cursor_line < 0 or cursor_line >= get_line_count():
		return

	# Validate via BookService
	var para_data: Dictionary = BookService.get_paragraph_at_line(file_path, line_number)
	if para_data.is_empty():
		return

	var paragraph: String = get_line(cursor_line)
	var words: PackedStringArray = paragraph.split(" ")

	begin_complex_operation()

	if operation == "delete":
		var delete_words: PackedStringArray = old_text.split(" ")
		if word_index >= 0 && word_index + delete_words.size() <= words.size():
			# Verify words match
			var matches: bool = true
			for k: int in range(delete_words.size()):
				if words[word_index + k] != delete_words[k]:
					matches = false
					break
			if matches:
				# Calculate character range to remove
				var start_col: int = 0
				for i: int in range(word_index):
					start_col += words[i].length() + 1
				var text_to_remove: String = ""
				for j: int in range(delete_words.size()):
					if j > 0:
						text_to_remove += " "
					text_to_remove += delete_words[j]
				remove_text(cursor_line, start_col, cursor_line, start_col + text_to_remove.length())

	elif operation == "insert":
		if word_index >= 0 && word_index <= words.size():
			# Calculate position BEFORE word at word_index
			var insert_col: int = 0
			for i: int in range(word_index):
				insert_col += words[i].length() + 1
			# insert_col is now at the start of word at word_index (or at end if word_index == words.size())
			# Insert text at this position
			insert_text(new_text, cursor_line, insert_col)
			# Add space after inserted text if not at end
			if word_index < words.size():
				insert_text(" ", cursor_line, insert_col + new_text.length())

	elif operation == "change":
		# For change operations, use word_index to find position
		# Then do a simple string replace within that position range
		if word_index >= 0 and word_index < words.size():
			# Calculate start column for this word
			var start_col: int = 0
			for i: int in range(word_index):
				start_col += words[i].length() + 1

			# Check if old_text appears at this position in the paragraph
			if paragraph.substr(start_col, old_text.length()) == old_text:
				var end_col: int = start_col + old_text.length()
				remove_text(cursor_line, start_col, cursor_line, end_col)
				insert_text(new_text, cursor_line, start_col)
			else:
				# Fallback: try to find old_text in the paragraph
				var pos: int = paragraph.find(old_text)
				if pos >= 0:
					var end_col: int = pos + old_text.length()
					remove_text(cursor_line, pos, cursor_line, end_col)
					insert_text(new_text, cursor_line, pos)

	end_complex_operation()

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		var is_meta_pressed: bool = key_event.meta_pressed
		var is_ctrl_pressed: bool = key_event.ctrl_pressed
		# Use Meta (Cmd) on macOS, Ctrl on other platforms
		var modifier_pressed: bool = is_meta_pressed or is_ctrl_pressed
		if key_event.pressed and modifier_pressed:
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
	font_size = max(font_size - 2, MIN_FONT_SIZE)
	add_theme_font_size_override("font_size", font_size)
	_set_editor_width()

func _set_editor_width() -> void:
	var line_length: int = AppConfig.get_editor_line_length()
	var line_width: float = 0.5 * font_size * line_length
	var margins : int = EDITOR_MARGIN;
	custom_minimum_size.x = min(line_width, get_parent().get_parent_area_size().x - margins)
	call_deferred('_ensure_caret_in_center_view')

func _on_editor_resized() -> void:
	call_deferred("_set_editor_width")
