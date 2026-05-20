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
	if DiffUtility.is_diff_meta(meta_str):
		var patch_info: Dictionary = DiffUtility.get_patch_info_from_meta(meta_str)
		if not patch_info.is_empty():
			EventBus.diff_span_clicked.emit(
				patch_info["operation"],
				patch_info["word_index"],
				patch_info.get("old_text", ""),
				patch_info.get("new_text", "")
			)
