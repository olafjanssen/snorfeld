extends CodeEdit

var current_file_path: String = ""
var current_paragraph_hash: String = ""

func _ready():
	var highlighter = load("res://scripts/markdown_highlighter.gd").new()
	syntax_highlighter = highlighter

	GlobalSignals.file_selected.connect(_on_file_selected)
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
		var paragraph_hash := _hash_paragraph(paragraph)
		if paragraph_hash != current_paragraph_hash:
			current_paragraph_hash = paragraph_hash
			GlobalSignals.paragraph_selected.emit(paragraph_hash, current_file_path)

func _hash_paragraph(paragraph: String) -> String:
	var hash_ctx := HashingContext.new()
	hash_ctx.start(HashingContext.HASH_MD5)
	hash_ctx.update(paragraph.to_utf8_buffer())
	var hash_bytes := hash_ctx.finish()
	return hash_bytes.hex_encode()
