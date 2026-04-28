extends Control

@onready var scroll: ScrollContainer = $ScrollContainer
@onready var rich_text: RichTextLabel = $ScrollContainer/RichTextContent
@onready var cursor_timer: Timer = $Timer

var text: String = ""
var cursor_pos: int = 0
var cursor_visible: bool = true
var selecting: bool = false
var selection_start: int = 0

# Public property for editor.gd to set/get text
var public_text: String:
	get:
		return text
	set(value):
		text = value
		_update_display()

func _ready():
	cursor_timer.start()
	_update_display()

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
		var pos: Vector2 = scroll.get_local_mouse_position()
		var rt_pos: Vector2 = rich_text.to_local(pos)
		var clicked_index: int = rich_text.get_letter_index_at_position(rt_pos)

		# Map BBCode index back to Markdown index
		cursor_pos = _bbcode_to_markdown_index(clicked_index, rich_text.text)

		if event.shift_pressed:
			_select_to(cursor_pos)
		else:
			selection_start = cursor_pos
			selecting = false

		_update_display()

func _bbcode_to_markdown_index(bbcode_pos: int, bbcode_text: String) -> int:
	# Convert BBCode character position back to Markdown position
	# by counting how many BBCode tags are before bbcode_pos
	var md_pos: int = bbcode_pos
	var i: int = 0

	while i < bbcode_pos and i < bbcode_text.length():
		if bbcode_text.substr(i, 7) == "[size=32]" or bbcode_text.substr(i, 7) == "[size=24]" or bbcode_text.substr(i, 7) == "[size=20]":
			md_pos -= 7
			i += 7
		elif bbcode_text.substr(i, 8) == "[/size]":
			md_pos -= 8
			i += 8
		elif bbcode_text.substr(i, 3) == "[b]":
			md_pos -= 3
			i += 3
		elif bbcode_text.substr(i, 4) == "[/b]":
			md_pos -= 4
			i += 4
		elif bbcode_text.substr(i, 3) == "[i]":
			md_pos -= 3
			i += 3
		elif bbcode_text.substr(i, 4) == "[/i]":
			md_pos -= 4
			i += 4
		else:
			i += 1

	return md_pos

func _markdown_to_bbcode_index(md_pos: int) -> int:
	# Convert Markdown position to equivalent BBCode position
	var bbcode: String = _markdown_to_bbcode(text.substr(0, md_pos))
	return bbcode.length()

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
	# Cursor blink disabled for now
	pass

func _update_display():
	var bbcode: String = _markdown_to_bbcode(text)

	# Selection highlighting (cursor removed for now)
	if selecting:
		var start_bbcode: int = _markdown_to_bbcode_index(selection_start)
		var end_bbcode: int = _markdown_to_bbcode_index(cursor_pos)
		if start_bbcode > end_bbcode:
			var temp_bb: int = start_bbcode
			start_bbcode = end_bbcode
			end_bbcode = temp_bb
		bbcode = (bbcode.substr(0, start_bbcode) +
			"[color=8080ff]" + bbcode.substr(start_bbcode, end_bbcode - start_bbcode) + "[/color]" +
			bbcode.substr(end_bbcode))

	if rich_text.text != bbcode:
		rich_text.text = bbcode

func _markdown_to_bbcode(md: String) -> String:
	var i: int = 0
	var result: String = ""
	var in_bold: bool = false
	var in_italic: bool = false

	while i < md.length():
		var c: String = md[i]
		var lookahead: String = ""
		if i + 1 < md.length():
			lookahead = md.substr(i, 2)

		# Check for bold ** at start of word/line
		if lookahead == "**" and (i == 0 or md[i-1] == " " or md[i-1] == "\n" or md[i-1] == "\t"):
			in_bold = not in_bold
			result += "[b]" if in_bold else "[/b]"
			i += 2
			continue

		# Check for bold __ at start of word/line
		if lookahead == "__" and (i == 0 or md[i-1] == " " or md[i-1] == "\n" or md[i-1] == "\t"):
			in_bold = not in_bold
			result += "[b]" if in_bold else "[/b]"
			i += 2
			continue

		# Check for italic * at start of word
		if c == "*" and (i == 0 or md[i-1] == " " or md[i-1] == "\n" or md[i-1] == "\t") and (i + 1 >= md.length() or md[i+1] != "*"):
			in_italic = not in_italic
			result += "[i]" if in_italic else "[/i]"
			i += 1
			continue

		# Check for italic _ at start of word
		if c == "_" and (i == 0 or md[i-1] == " " or md[i-1] == "\n" or md[i-1] == "\t") and (i + 1 >= md.length() or md[i+1] != "_"):
			in_italic = not in_italic
			result += "[i]" if in_italic else "[/i]"
			i += 1
			continue

		result += c
		i += 1

	# Close any open tags
	if in_bold:
		result += "[/b]"
	if in_italic:
		result += "[/i]"

	# Post-process headers: lines starting with #
	var lines := result.split("\n")
	result = ""
	for line in lines:
		var stripped := line.strip_edges()
		if stripped.begins_with("#"):
			var level: int = 0
			while level < stripped.length() and stripped[level] == "#":
				level += 1
			var header_text: String = stripped.substr(level).strip_edges()
			var size: int = 32
			if level >= 2:
				size = 24
			if level >= 3:
				size = 20
			line = "[size=%d]%s[/size]" % [size, header_text]
		result += line + "\n"

	return result
