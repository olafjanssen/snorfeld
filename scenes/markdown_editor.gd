extends Control

@onready var scroll: ScrollContainer = $ScrollContainer
@onready var markdown_label: MarkdownLabel = $ScrollContainer/MarginContainer/MarkdownContent
@onready var cursor_timer: Timer = $Timer

var text: String = ""
var cursor_pos: int = 0
var cursor_visible: bool = true
var selecting: bool = false
var selection_start: int = 0

# Public methods for external access
func set_text(p_text: String):
	text = p_text
	_update_display()

func get_text() -> String:
	return text

func _ready():
	cursor_timer.start()
	_update_display()
	GlobalSignals.file_selected.connect(_on_file_selected)

func _on_file_selected(path: String):
	if FileAccess.file_exists(path):
		var content: String = FileAccess.get_file_as_string(path)
		set_text(content)

func _input(event: InputEvent):
	if not has_focus():
		return

	if event is InputEventKey:
		_handle_key(event)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_mouse_click(event)

func _handle_key(event: InputEventKey):
	if not has_focus():
		return

	if event.pressed:
		return

	if event.is_echo():
		return

	var ctrl_pressed: bool = event.ctrl_pressed
	var shift_pressed: bool = event.shift_pressed

	if event.keycode == KEY_BACKSPACE:
		_delete_at_cursor()
	elif event.keycode == KEY_DELETE:
		_delete_after_cursor()
	elif event.keycode == KEY_ENTER:
		_insert_at_cursor("\n")
	elif event.keycode == KEY_LEFT:
		_move_cursor(-1, shift_pressed)
	elif event.keycode == KEY_RIGHT:
		_move_cursor(1, shift_pressed)
	elif event.keycode == KEY_UP:
		_move_cursor_up(shift_pressed)
	elif event.keycode == KEY_DOWN:
		_move_cursor_down(shift_pressed)
	elif event.keycode == KEY_HOME and ctrl_pressed:
		_move_cursor(-cursor_pos, shift_pressed)
	elif event.keycode == KEY_END and ctrl_pressed:
		_move_cursor(text.length() - cursor_pos, shift_pressed)
	elif event.keycode == KEY_A and ctrl_pressed:
		selection_start = 0
		cursor_pos = text.length()
		_update_display()
	elif event.keycode == KEY_C and ctrl_pressed:
		_copy_to_clipboard()
	elif event.keycode == KEY_V and ctrl_pressed:
		_paste_from_clipboard()
	elif event.keycode == KEY_X and ctrl_pressed:
		_copy_to_clipboard()
		_delete_selection()
	elif event.unicode != 0:
		_insert_at_cursor(char(event.unicode))
		selecting = false

	_update_display()

func _handle_mouse_click(event: InputEventMouseButton):
	if not has_focus():
		grab_focus()

	if event.pressed:
		var line_height: float = markdown_label.get_line_height(0)
		var scrollbar = scroll.get_v_scrollbar()
		var line_count: int = max(1, text.count("\n") + 1)
		var char_per_line: int = int(text.length() / float(line_count))
		var clicked_line: int = int(scroll.get_local_mouse_position().y / line_height) + (scrollbar.value if scrollbar else 0)
		cursor_pos = min(clicked_line * char_per_line, text.length())

		if event.shift_pressed:
			_select_to(cursor_pos)
		else:
			selection_start = cursor_pos
			selecting = false

		_update_display()

func _move_cursor(delta: int, shift: bool):
	if shift and not selecting:
		selection_start = cursor_pos
		selecting = true

	cursor_pos = clamp(cursor_pos + delta, 0, text.length())

	if shift:
		_ensure_selection_valid()
	else:
		selecting = false

func _move_cursor_up(shift: bool):
	var lines: PackedStringArray = text.split("\n")
	var current_line: int = 0
	var char_count: int = 0
	for i in lines.size():
		if char_count + lines[i].length() >= cursor_pos:
			current_line = i
			break
		char_count += lines[i].length() + 1

	if current_line > 0:
		var prev_line_length: int = lines[current_line - 1].length()
		var x_offset: int = cursor_pos - char_count + lines[current_line].length()
		var new_pos: int = char_count - lines[current_line].length() - 1 + min(x_offset, prev_line_length)
		cursor_pos = clamp(new_pos, 0, text.length())

		if shift:
			if not selecting:
				selection_start = cursor_pos
				selecting = true
			_select_to(cursor_pos)
		else:
			_select_to(cursor_pos)

		_ensure_selection_valid()
		_update_display()

func _move_cursor_down(shift: bool):
	var lines: PackedStringArray = text.split("\n")
	var current_line: int = 0
	var char_count: int = 0
	for i in lines.size():
		if char_count + lines[i].length() >= cursor_pos:
			current_line = i
			break
		char_count += lines[i].length() + 1

	if current_line < lines.size() - 1:
		var x_offset: int = cursor_pos - char_count + lines[current_line].length()
		char_count += lines[current_line].length() + 1
		var new_pos: int = char_count + min(x_offset, lines[current_line + 1].length())
		cursor_pos = clamp(new_pos, 0, text.length())

		if shift:
			if not selecting:
				selection_start = cursor_pos
				selecting = true
			_select_to(cursor_pos)
		else:
			_select_to(cursor_pos)

		_ensure_selection_valid()
		_update_display()

func _select_to(pos: int):
	selecting = true
	if pos < selection_start:
		var temp: int = selection_start
		selection_start = pos
		cursor_pos = temp
	else:
		cursor_pos = pos

func _ensure_selection_valid():
	if cursor_pos < selection_start:
		var temp: int = cursor_pos
		cursor_pos = selection_start
		selection_start = temp

func _delete_at_cursor():
	if selecting:
		_delete_selection()
		return

	if cursor_pos > 0:
		text = text.substr(0, cursor_pos - 1) + text.substr(cursor_pos)
		cursor_pos -= 1
		_update_selection()

func _delete_after_cursor():
	if selecting:
		_delete_selection()
		return

	if cursor_pos < text.length():
		text = text.substr(0, cursor_pos) + text.substr(cursor_pos + 1)
		_update_selection()

func _delete_selection():
	if not selecting:
		return

	var start: int = selection_start
	var end: int = cursor_pos
	if start > end:
		var temp: int = start
		start = end
		end = temp

	text = text.substr(0, start) + text.substr(end)
	cursor_pos = start
	selecting = false
	_update_selection()

func _insert_at_cursor(ch: String):
	if selecting:
		_delete_selection()

	text = text.substr(0, cursor_pos) + ch + text.substr(cursor_pos)
	cursor_pos += ch.length()
	selecting = false
	_update_selection()

func _copy_to_clipboard():
	if selecting:
		var start: int = selection_start
		var end: int = cursor_pos
		if start > end:
			var temp: int = start
			start = end
			end = temp
		var selection: String = text.substr(start, end - start)
		DisplayServer.clipboard_set(selection)
	elif cursor_pos < text.length():
		DisplayServer.clipboard_set(text.substr(cursor_pos, 1))

func _paste_from_clipboard():
	if selecting:
		_delete_selection()

	var clipboard: String = DisplayServer.clipboard_get()
	if clipboard != null and clipboard.length() > 0:
		_insert_at_cursor(clipboard)

func _update_selection():
	selection_start = cursor_pos
	selecting = false

func _on_cursor_blink():
	pass

func _update_display():
	markdown_label.markdown_text = text
	markdown_label.visible_characters = -1
