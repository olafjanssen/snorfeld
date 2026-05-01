extends CodeEdit

var current_file_path: String = ""
var current_paragraph_hash: String = ""

func _ready():
	var highlighter = load("res://scripts/markdown_highlighter.gd").new()
	syntax_highlighter = highlighter

	GlobalSignals.file_selected.connect(_on_file_selected)
	GlobalSignals.apply_diff_patch.connect(_on_apply_diff_patch)
	caret_changed.connect(_on_cursor_changed)

func _on_file_selected(path: String):
	current_file_path = path
	if FileAccess.file_exists(path):
		var content: String = FileAccess.get_file_as_string(path)
		set_text(content)

func _on_cursor_changed():
	var cursor_line := get_caret_line()
	var text := get_text()
	var lines := text.split("\n")
	if cursor_line >= 0 and cursor_line < lines.size():
		var paragraph := lines[cursor_line]
		# Only process non-empty paragraphs
		if paragraph.length() > 0:
			var paragraph_hash := _hash_paragraph(paragraph)
			if paragraph_hash != current_paragraph_hash:
				current_paragraph_hash = paragraph_hash
				GlobalSignals.paragraph_selected.emit(paragraph_hash, current_file_path, paragraph)

func _hash_paragraph(paragraph: String) -> String:
	var hash_ctx := HashingContext.new()
	hash_ctx.start(HashingContext.HASH_MD5)
	hash_ctx.update(paragraph.to_utf8_buffer())
	var hash_bytes := hash_ctx.finish()
	return hash_bytes.hex_encode()

func _on_apply_diff_patch(paragraph_hash: String, file_path: String, current_text: String, operation: String, word_index: int, new_text: String):
	# Only apply if this is the current paragraph we're looking at
	var cursor_line := get_caret_line()
	var text := get_text()
	var lines := text.split("\n")

	if cursor_line < 0 or cursor_line >= lines.size():
		return

	var current_paragraph = lines[cursor_line]
	var current_hash = _hash_paragraph(current_paragraph)

	# Verify this is the paragraph we expect (hash matches and file matches)
	if current_hash != paragraph_hash or current_file_path != file_path:
		return

	# Apply the patch
	var words := current_paragraph.split(" ")

	match operation:
		"delete":
			# Remove the word at word_index
			if word_index >= 0 and word_index < words.size():
				words.remove_at(word_index)
				current_paragraph = " ".join(words)
		"insert":
			# Insert new_text at word_index
			if word_index >= 0 and word_index <= words.size():
				words.insert(word_index, new_text)
				current_paragraph = " ".join(words)
		"change":
			# Replace the word at word_index with new_text
			if word_index >= 0 and word_index < words.size():
				words[word_index] = new_text
				current_paragraph = " ".join(words)

	# Update the line in the editor
	if current_paragraph != lines[cursor_line]:
		lines[cursor_line] = current_paragraph
		set_text("\n".join(lines))
		# Move cursor to maintain position
		set_caret_line(cursor_line)
		set_caret_column(0)
		# Re-trigger paragraph selection to update diff display
		current_paragraph_hash = _hash_paragraph(current_paragraph)
		GlobalSignals.paragraph_selected.emit(current_paragraph_hash, current_file_path, current_paragraph)
