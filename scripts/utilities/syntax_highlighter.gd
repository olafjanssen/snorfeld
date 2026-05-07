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

# gdlint:ignore-function:long-function
func _get_line_syntax_highlighting(line: int) -> Dictionary:
	var text: String = get_text_edit().get_line(line)
	var length: int = text.length()

	var tokens: Dictionary = {}
	var pos: int = 0
	var in_bold: bool = false
	var in_italic: bool = false
	var in_dialog: bool = false

	while pos < length:
		# Process header tokens at the start of a line
		if pos == 0:
			pos = _process_header_tokens(text, length, tokens, pos)
			if pos >= length:
				break

		# Process inline markers
		var marker_found: bool = false

		# Check for bold markers (**)
		if pos + 1 < length and text.substr(pos, 2) == "**":
			tokens[pos] = {"color": _get_token_color(TOKEN_BOLD if not in_bold else TOKEN_NORMAL)}
			in_bold = !in_bold
			pos += 2
			marker_found = true

		# Check for italic markers (* or _)
		elif text[pos] == "*" or text[pos] == "_":
			tokens[pos] = {"color": _get_token_color(TOKEN_ITALIC if not in_italic else TOKEN_NORMAL)}
			in_italic = !in_italic
			pos += 1
			marker_found = true

		# Check for dialog quotes (")
		elif text[pos] == "\"":
			tokens[pos] = {"color": _get_token_color(TOKEN_DIALOG if not in_dialog else TOKEN_NORMAL)}
			in_dialog = !in_dialog
			pos += 1
			marker_found = true

		if not marker_found:
			# Color regular text based on active states
			if in_dialog:
				tokens[pos] = {"color": _get_token_color(TOKEN_DIALOG)}
			elif in_bold:
				tokens[pos] = {"color": _get_token_color(TOKEN_BOLD)}
			elif in_italic:
				tokens[pos] = {"color": _get_token_color(TOKEN_ITALIC)}
			pos += 1

	return tokens

## Process header tokens at the start of a line
func _process_header_tokens(text: String, length: int, tokens: Dictionary, pos: int) -> int:
	for i in range(MAX_HEADER_LEVEL, 0, -1):
		if pos + i <= length and text.substr(pos, i) == "#".repeat(i) and (pos + i < length and text[pos + i] == " "):
			for j in range(i):
				tokens[pos + j] = {"color": _get_token_color(TOKEN_HEADER)}
			# Space after # is part of the header
			tokens[pos + i] = {"color": _get_token_color(TOKEN_HEADER)}
			return pos + i + 1
	return pos
