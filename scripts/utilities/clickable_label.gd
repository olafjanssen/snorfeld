extends RichTextLabel

class_name ClickableRichTextLabel

# Pipe as delimiter - must match DiffUtility
const DELIMITER := "|"

# URL encoded character replacements
const URL_ENCODED_SPACE := "%20"
const URL_ENCODED_COLON := "%3A"
const URL_ENCODED_PIPE := "%7C"

# Minimum parts for a valid diff meta string
const MIN_META_PARTS: int = 3

func _ready():
	connect("meta_clicked", Callable(self, "_on_meta_clicked"))

func _on_meta_clicked(meta: Variant):
	var meta_str: String = str(meta)
	if _is_diff_meta(meta_str):
		var parts: PackedStringArray = meta_str.split(DELIMITER, MIN_META_PARTS)
		if parts.size() >= MIN_META_PARTS:
			var operation: String = parts[0]
			var word_index: int = int(parts[1])
			var full_text: String = _url_decode(parts[2])
			EventBus.diff_span_clicked.emit(operation, word_index, full_text)

## Check if meta string is a diff operation
func _is_diff_meta(meta_str: String) -> bool:
	return (meta_str.begins_with("delete" + DELIMITER) or
		meta_str.begins_with("insert" + DELIMITER) or
		meta_str.begins_with("change" + DELIMITER))

func _url_decode(encoded: String) -> String:
	# URL decoding for our use case
	return encoded.replace(URL_ENCODED_SPACE, " ").replace(URL_ENCODED_COLON, ":").replace(URL_ENCODED_PIPE, "|")
