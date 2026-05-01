extends RichTextLabel

class_name ClickableRichTextLabel

signal diff_span_clicked(operation: String, word_index: int, text: String)

func _ready():
	connect("meta_clicked", Callable(self, "_on_meta_clicked"))

func _on_meta_clicked(meta: Variant):
	var meta_str = str(meta)
	if meta_str.begins_with("delete:") or meta_str.begins_with("insert:") or meta_str.begins_with("change:"):
		var parts = meta_str.split(":", 2)
		if parts.size() >= 3:
			var operation = parts[0]
			var word_index = int(parts[1])
			var text = _url_decode(parts[2])
			emit_signal("diff_span_clicked", operation, word_index, text)

func _url_decode(encoded: String) -> String:
	# Replace %20 with space (simple URL decoding for our use case)
	return encoded.replace("%20", " ")
