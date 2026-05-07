extends SyntaxHighlighter

# Token types
const TOKEN_NORMAL: int = 0
const TOKEN_HEADER: int = 1
const TOKEN_BOLD: int = 2
const TOKEN_ITALIC: int = 3
const TOKEN_DIALOG: int = 4

# Maximum header level to check
const MAX_HEADER_LEVEL: int = 6

# Theme color names for syntax highlighting
const THEME_COLORS: Dictionary = {
	TOKEN_NORMAL: "syntax_normal",
	TOKEN_HEADER: "syntax_header",
	TOKEN_BOLD: "syntax_bold",
	TOKEN_ITALIC: "syntax_italic",
	TOKEN_DIALOG: "syntax_dialog"
}

# State change flags
const STATE_NO_CHANGE: int = 0
const STATE_BOLD_CHANGED: int = 1
const STATE_ITALIC_CHANGED: int = 2
const STATE_DIALOG_CHANGED: int = 3

func _get_theme_color(color_name: String) -> Color:
	return get_text_edit().get_theme_color(color_name, "SyntaxHighlighter")

func _get_token_color(token_type: int) -> Color:
	var color_name: String = THEME_COLORS.get(token_type, "")
	return _get_theme_color(color_name) if color_name else Color(1, 1, 1)

func _color_current_char(
	tokens: Dictionary, pos: int, in_bold: bool, in_italic: bool, in_dialog: bool
) -> void:
	if in_dialog:
		tokens[pos] = {"color": _get_token_color(TOKEN_DIALOG)}
	elif in_bold:
		tokens[pos] = {"color": _get_token_color(TOKEN_BOLD)}
	elif in_italic:
		tokens[pos] = {"color": _get_token_color(TOKEN_ITALIC)}

func _process_header_tokens(text: String, length: int, tokens: Dictionary, pos: int) -> int:
	for i in range(MAX_HEADER_LEVEL, 0, -1):
		if pos + i <= length and text.substr(pos, i) == "#".repeat(i):
			if pos + i < length and text[pos + i] == " ":
				for j in range(i):
					tokens[pos + j] = {"color": _get_token_color(TOKEN_HEADER)}
				tokens[pos + i] = {"color": _get_token_color(TOKEN_HEADER)}
				return pos + i + 1
	return pos

func _process_bold(text: String, length: int, tokens: Dictionary, pos: int, in_bold: bool) -> int:
	if pos + 1 < length and text.substr(pos, 2) == "**":
		tokens[pos] = {"color": _get_token_color(TOKEN_BOLD if not in_bold else TOKEN_NORMAL)}
		return pos + 2
	return -1

func _process_italic(text: String, tokens: Dictionary, pos: int, in_italic: bool) -> int:
	if text[pos] == "*" or text[pos] == "_":
		tokens[pos] = {"color": _get_token_color(TOKEN_ITALIC if not in_italic else TOKEN_NORMAL)}
		return pos + 1
	return -1

func _process_dialog(text: String, tokens: Dictionary, pos: int) -> int:
	if text[pos] == "\"":
		tokens[pos] = {"color": _get_token_color(TOKEN_DIALOG)}
		return pos + 1
	return -1

func _process_inline_markers(
	text: String,
	length: int,
	tokens: Dictionary,
	pos: int,
	in_bold: bool,
	in_italic: bool,
	in_dialog: bool
) -> Dictionary:
	var new_pos: int
	var state_changes: Dictionary = {"pos": pos, "bold": in_bold, "italic": in_italic, "dialog": in_dialog}

	new_pos = _process_bold(text, length, tokens, pos, in_bold)
	if new_pos != -1:
		state_changes["pos"] = new_pos
		state_changes["bold"] = !in_bold
		return state_changes

	new_pos = _process_italic(text, tokens, pos, in_italic)
	if new_pos != -1:
		state_changes["pos"] = new_pos
		state_changes["italic"] = !in_italic
		return state_changes

	new_pos = _process_dialog(text, tokens, pos)
	if new_pos != -1:
		state_changes["pos"] = new_pos
		state_changes["dialog"] = !in_dialog
		return state_changes

	return state_changes

func _get_line_syntax_highlighting(line: int) -> Dictionary:
	var text: String = get_text_edit().get_line(line)
	var length: int = text.length()

	var tokens: Dictionary = {}
	var pos: int = 0
	var in_bold: bool = false
	var in_italic: bool = false
	var in_dialog: bool = false

	while pos < length:
		if pos == 0:
			pos = _process_header_tokens(text, length, tokens, pos)
			if pos >= length:
				break

		var changes: Dictionary = _process_inline_markers(
			text, length, tokens, pos, in_bold, in_italic, in_dialog
		)
		pos = changes["pos"]
		in_bold = changes["bold"]
		in_italic = changes["italic"]
		in_dialog = changes["dialog"]

		if pos == changes["pos"]:
			_color_current_char(tokens, pos, in_bold, in_italic, in_dialog)
			pos += 1

	return tokens
