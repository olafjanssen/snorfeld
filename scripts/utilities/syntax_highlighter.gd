extends SyntaxHighlighter

# Token types
const TOKEN_NORMAL = 0
const TOKEN_HEADER = 1
const TOKEN_BOLD = 2
const TOKEN_ITALIC = 3
const TOKEN_DIALOG = 4

# Colors for each token type
const COLORS = {
	TOKEN_NORMAL: Color("1e1e1e"),
	TOKEN_HEADER: Color(0.13, 0.522, 0.724, 1.0),
	TOKEN_BOLD: Color(0.0, 0.0, 0.0),
	TOKEN_ITALIC: Color("1e1e1ec8"),
	TOKEN_DIALOG: Color("1e1e1ec8")
}

func _get_token_color(index: int) -> Color:
	return COLORS.get(index, Color(1, 1, 1))

func _get_line_syntax_highlighting(line: int) -> Dictionary:
	var text: String = get_text_edit().get_line(line)
	var length : int = len(text)

	var tokens = {}
	var pos: int = 0
	var in_bold: bool = false
	var in_italic: bool = false
	var in_dialog: bool = false

	while pos < length:
		# Check for headers at start of line
		if pos == 0:
			for i in range(6, 0, -1):
				if pos + i <= length and text.substr(pos, i) == "#".repeat(i) and (pos + i < length and text[pos + i] == " "):
					for j in range(i):
						tokens[pos + j] = {"color": _get_token_color(TOKEN_HEADER)}
					pos += i + 1
					break
			# If we reached end of line after header, continue to next iteration
			if pos >= length:
				continue

		# Check for bold
		if pos + 1 < length and text.substr(pos, 2) == "**":
			in_bold = !in_bold
			if in_bold:
				tokens[pos] = {"color": _get_token_color(TOKEN_BOLD)}
			else:
				tokens[pos] = {"color": _get_token_color(TOKEN_NORMAL)}
			pos += 2
			continue

		# Check for italic
		if text[pos] == "*" or text[pos] == "_":
			in_italic = !in_italic
			if in_italic:
				tokens[pos] = {"color": _get_token_color(TOKEN_ITALIC)}
			else:
				tokens[pos] = {"color": _get_token_color(TOKEN_NORMAL)}
			pos += 1
			continue

		# Check for dialog
		if text[pos] == "\"":
			in_dialog = !in_dialog
			if in_dialog and pos + 1 < length:
				tokens[pos+1] = {"color": _get_token_color(TOKEN_DIALOG)}
			elif not in_dialog and pos - 1 >= 0:
				tokens[pos-1] = {"color": _get_token_color(TOKEN_NORMAL)}
			pos += 1
			continue

		pos += 1

	return tokens
