extends RichTextLabel

class_name ClickableRichTextLabel

# Pipe as delimiter - must match DiffUtility
const DELIMITER := "|"

signal diff_span_clicked(operation: String, word_index: int, text: String)

func _ready():
	connect("meta_clicked", Callable(self, "_on_meta_clicked"))

func _on_meta_clicked(meta: Variant):
	var meta_str = str(meta)
	if meta_str.begins_with("delete" + DELIMITER) or meta_str.begins_with("insert" + DELIMITER) or meta_str.begins_with("change" + DELIMITER):
		var parts = meta_str.split(DELIMITER, 3)
		if parts.size() >= 3:
			var operation = parts[0]
			var word_index = int(parts[1])
			var full_text = _url_decode(parts[2])
			emit_signal("diff_span_clicked", operation, word_index, full_text)

func _url_decode(encoded: String) -> String:
	# URL decoding for our use case
	return encoded.replace("%20", " ").replace("%3A", ":").replace("%7C", "|")
