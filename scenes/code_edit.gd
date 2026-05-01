extends CodeEdit

var current_file_path: String = ""
# Map from line number to original hash for that paragraph
var paragraph_original_hashes := {}
# Map from line number to current hash for that paragraph
var paragraph_current_hashes := {}

func _ready():
	var highlighter = load("res://scripts/markdown_highlighter.gd").new()
	syntax_highlighter = highlighter

	GlobalSignals.file_selected.connect(_on_file_selected)
	GlobalSignals.apply_diff_patch.connect(_on_apply_diff_patch)
	caret_changed.connect(_on_cursor_changed)

func _on_file_selected(path: String):
	current_file_path = path
	paragraph_original_hashes = {}
	paragraph_current_hashes = {}
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
			var current_hash := _hash_paragraph(paragraph)

			# Check if this line has an original hash
			if paragraph_original_hashes.has(cursor_line):
				# If current hash doesn't match current hash, user made manual edit
				if paragraph_current_hashes.has(cursor_line) and current_hash != paragraph_current_hashes[cursor_line]:
					# User manually edited - invalidate original hash
					paragraph_original_hashes.erase(cursor_line)
					paragraph_current_hashes.erase(cursor_line)
					# Set new original hash to current
					paragraph_original_hashes[cursor_line] = current_hash

			# If this line doesn't have an original hash yet, set it
			if not paragraph_original_hashes.has(cursor_line):
				paragraph_original_hashes[cursor_line] = current_hash

			# Update current hash
			paragraph_current_hashes[cursor_line] = current_hash

			# Emit signal with original hash for this line
			GlobalSignals.paragraph_selected.emit(
				paragraph_original_hashes[cursor_line],
				current_file_path,
				paragraph
			)

func _hash_paragraph(paragraph: String) -> String:
	var hash_ctx := HashingContext.new()
	hash_ctx.start(HashingContext.HASH_MD5)
	hash_ctx.update(paragraph.to_utf8_buffer())
	var hash_bytes := hash_ctx.finish()
	return hash_bytes.hex_encode()

func _on_apply_diff_patch(original_hash: String, file_path: String, operation: String, word_index: int, new_text: String):
	# Only apply if this is the current file
	if current_file_path != file_path:
		return

	var cursor_line := get_caret_line()
	var text := get_text()
	var lines := text.split("\n")

	if cursor_line < 0 or cursor_line >= lines.size():
		return

	# Verify this is the paragraph we expect (original hash matches)
	if not paragraph_original_hashes.has(cursor_line) or paragraph_original_hashes[cursor_line] != original_hash:
		return

	var current_paragraph = lines[cursor_line]

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
		# Update current hash but keep original hash (so more patches can be applied)
		paragraph_current_hashes[cursor_line] = _hash_paragraph(current_paragraph)
		# Re-trigger paragraph selection to update diff display (with same original hash)
		GlobalSignals.paragraph_selected.emit(original_hash, current_file_path, current_paragraph)
