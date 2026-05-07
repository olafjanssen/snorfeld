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
const THEME_COLORS = {
	TOKEN_NORMAL: "syntax_normal",
	TOKEN_HEADER: "syntax_header",
	TOKEN_BOLD: "syntax_bold",
	TOKEN_ITALIC: "syntax_italic",
	TOKEN_DIALOG: "syntax_dialog"
}

func _get_theme_color(color_name: String) -> Color:
	var text_edit: TextEdit = get_text_edit()
	return text_edit.get_theme_color(color_name, "SyntaxHighlighter")

func _get_token_color(index: int) -> Color:
	var color_name: String = THEME_COLORS.get(index, "")
	if color_name:
		return _get_theme_color(color_name)
	return Color(1, 1, 1)

func _get_line_syntax_highlighting(line: int) -> Dictionary:
	var text: String = get_text_edit().get_line(line)
	var length: int = len(text)

	var tokens: Dictionary = {}
	var pos: int = 0
	var in_bold: bool = false
	var in_italic: bool = false
	var in_dialog: bool = false

	while pos < length:
		if pos == 0:
			pos = _process_header_tokens(text, length, tokens, pos)
			if pos >= length:
				continue

		var new_pos: int

		new_pos = _process_bold(text, length, tokens, pos, in_bold)
		if new_pos != -1:
			in_bold = !in_bold
			pos = new_pos
			continue

		new_pos = _process_italic(text, tokens, pos, in_italic)
		if new_pos != -1:
			in_italic = !in_italic
			pos = new_pos
			continue

		new_pos = _process_dialog(text, length, tokens, pos, in_dialog)
		if new_pos != -1:
			in_dialog = !in_dialog
			pos = new_pos
			continue

		pos += 1

	return tokens

## Process header tokens at the start of a line
func _process_header_tokens(text: String, length: int, tokens: Dictionary, pos: int) -> int:
	for i in range(MAX_HEADER_LEVEL, 0, -1):
		if pos + i <= length and text.substr(pos, i) == "#".repeat(i) and (pos + i < length and text[pos + i] == " "):
			for j in range(i):
				tokens[pos + j] = {"color": _get_token_color(TOKEN_HEADER)}
			return pos + i + 1
	return pos

## Process bold markdown tokens (**)
## Returns new position or -1 if not processed
func _process_bold(text: String, length: int, tokens: Dictionary, pos: int, in_bold: bool) -> int:
	if pos + 1 < length and text.substr(pos, 2) == "**":
		tokens[pos] = {"color": _get_token_color(TOKEN_BOLD if not in_bold else TOKEN_NORMAL)}
		return pos + 2
	return -1

## Process italic markdown tokens (* or _)
## Returns new position or -1 if not processed
func _process_italic(text: String, tokens: Dictionary, pos: int, in_italic: bool) -> int:
	if text[pos] == "*" or text[pos] == "_":
		tokens[pos] = {"color": _get_token_color(TOKEN_ITALIC if not in_italic else TOKEN_NORMAL)}
		return pos + 1
	return -1

## Process dialog quotes
## Returns new position or -1 if not processed
func _process_dialog(text: String, length: int, tokens: Dictionary, pos: int, in_dialog: bool) -> int:
	if text[pos] == "\"":
		if in_dialog and pos + 1 < length:
			tokens[pos+1] = {"color": _get_token_color(TOKEN_DIALOG)}
		elif not in_dialog and pos - 1 >= 0:
			tokens[pos-1] = {"color": _get_token_color(TOKEN_NORMAL)}
		return pos + 1
	return -1
