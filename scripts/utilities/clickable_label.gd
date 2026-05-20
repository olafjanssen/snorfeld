extends RichTextLabel

class_name ClickableRichTextLabel

# Pipe as delimiter - must match DiffUtility
const DELIMITER := "|"

# Minimum parts for a valid diff meta string
const MIN_META_PARTS: int = 3

func _ready():
	connect("meta_clicked", Callable(self, "_on_meta_clicked"))

func _on_meta_clicked(meta: Variant):
	var meta_str: String = str(meta)
	if _is_diff_meta(meta_str):
		var parts: PackedStringArray = meta_str.split(DELIMITER)
		if parts.size() >= MIN_META_PARTS:
			var operation: String = parts[0]
			var word_index: int = int(parts[1])
			# For change operations, meta has 4 parts: operation|index|base64_old|base64_new
			# For insert/delete, meta has 3 parts: operation|index|base64_text
			if operation == "change" and parts.size() >= 4:
				var old_text: String = Marshalls.base64_to_utf8(parts[2])
				var new_text: String = Marshalls.base64_to_utf8(parts[3])
				EventBus.diff_span_clicked.emit(operation, word_index, old_text, new_text)
			else:
				var full_text: String = Marshalls.base64_to_utf8(parts[2])
				# For insert/delete, pass empty string for new_text
				EventBus.diff_span_clicked.emit(operation, word_index, full_text, "")

## Check if meta string is a diff operation
func _is_diff_meta(meta_str: String) -> bool:
	return (meta_str.begins_with("delete" + DELIMITER) or
		meta_str.begins_with("insert" + DELIMITER) or
		meta_str.begins_with("change" + DELIMITER))
