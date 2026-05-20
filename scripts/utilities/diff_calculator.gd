# Diff Utility for GDScript
# Word-level diff for grammar corrections.

# gdlint:ignore-file:file-length,too-many-params,long-line

class_name DiffUtility

enum Operation {
	DELETE,
	INSERT,
	EQUAL
}

class Diff:
	var operation: Operation
	var text: String

	func _init(op: Operation, txt: String):
		operation = op
		text = txt

# Use pipe as delimiter - URL-safe and can be properly escaped
const DELIMITER := "|"

# Look-ahead limit for matching words in diff algorithm
const MAX_LOOK_AHEAD := 5

# BBCode tag lengths
const URL_TAG_OPEN_LENGTH := 5  # Length of "[url="
const URL_TAG_CLOSE_LENGTH := 6  # Length of "[/url]"

# Encode text for URL meta using Base64 to handle all special characters
func _encode_text(text: String) -> String:
	return Marshalls.utf8_to_base64(text)
	
var _control: Control

func set_control(control: Control) -> void:
	_control = control

# Get the bgcolor for an operation type from theme
func _get_bgcolor(operation: String) -> String:
	var color_name: String = ""
	match operation:
		"delete": color_name = "diff_delete_bg"
		"insert": color_name = "diff_insert_bg"
		"change": color_name = "diff_change_bg"
	return _control.get_theme_color(color_name, "DiffCalculator").to_html()

# Helper to merge adjacent spans of the same type
func _merge_adjacent_spans(bbcode: String) -> String:
	# Parse the BBCode and find adjacent spans of the same type
	var spans: Array[Dictionary] = _parse_spans(bbcode)

	# Merge consecutive spans of the same type
	var merged_spans: Array[Dictionary] = _merge_consecutive_spans(spans)

	# Rebuild the BBCode with merged spans
	return _rebuild_bbcode_from_spans(bbcode, merged_spans)


## Helper functions for _merge_adjacent_spans

func _parse_spans(bbcode: String) -> Array:
	var spans: Array[Dictionary] = []
	var i: int = 0
	var length: int = bbcode.length()

	while i < length:
		if bbcode.substr(i, URL_TAG_OPEN_LENGTH) == "[url=":
			var span: Dictionary = _parse_single_span(bbcode, i)
			if span != {}:
				spans.append(span)
				i = span["end"]
			continue
		i += 1
	return spans


# gdlint:ignore-function:long-function
func _parse_single_span(bbcode: String, start_pos: int) -> Dictionary:
	var i: int = start_pos
	var url_end: int = bbcode.find("]", i)
	if url_end == -1:
		return {}

	# Extract meta: operationDELIMITERword_indexDELIMITERencoded_text
	var meta: String = bbcode.substr(i + URL_TAG_OPEN_LENGTH, url_end - (i + URL_TAG_OPEN_LENGTH))
	var meta_parts: PackedStringArray = meta.split(DELIMITER, 2)
	if meta_parts.size() < 2:
		return {}

	var operation: String = meta_parts[0]
	var bgcolor: String = _get_bgcolor(operation)

	# Find the bgcolor tag
	var bgcolor_start: int = bbcode.find("[bgcolor=" + bgcolor + "]", url_end)
	if bgcolor_start == -1:
		return {}

	var bgcolor_end: int = bbcode.find("[/bgcolor]", bgcolor_start)
	if bgcolor_end == -1:
		return {}

	var text_start: int = bgcolor_start + ("[bgcolor=" + bgcolor + "]").length()
	var text_content: String = bbcode.substr(text_start, bgcolor_end - text_start)
	var url_close: int = bbcode.find("[/url]", bgcolor_end)
	if url_close == -1:
		return {}
	var url_close_end: int = url_close + URL_TAG_CLOSE_LENGTH

	return {
		"start": start_pos,
		"end": url_close_end,
		"operation": operation,
		"meta": meta,
		"bgcolor": bgcolor,
		"text": text_content
	}


func _merge_consecutive_spans(spans: Array[Dictionary]) -> Array[Dictionary]:
	var merged_spans: Array[Dictionary] = []
	var current_merge: Dictionary
	var has_current: bool = false

	for span: Dictionary in spans:
		if not has_current:
			current_merge = span
			has_current = true
		elif current_merge["operation"] == span["operation"]:
			if _are_spans_consecutive(current_merge, span):
				current_merge = _merge_two_spans(current_merge, span)
			else:
				merged_spans.append(current_merge)
				current_merge = span
		else:
			# Different operation
			merged_spans.append(current_merge)
			current_merge = span

	if has_current:
		merged_spans.append(current_merge)
	return merged_spans


func _are_spans_consecutive(span1: Dictionary, span2: Dictionary) -> bool:
	# Check if word indices are consecutive
	var parts1: PackedStringArray = span1["meta"].split(DELIMITER, 2)
	var parts2: PackedStringArray = span2["meta"].split(DELIMITER, 2)

	if parts1.size() < 2 or parts2.size() < 2:
		return false

	# For change ops, meta has 4 parts: operation|index|base64_old|base64_new
	# For insert/delete, meta has 3 parts: operation|index|base64_text
	# parts[1] is the word_index
	var word_idx1: int = int(parts1[1])
	var word_idx2: int = int(parts2[1])

	return word_idx2 == word_idx1 + span1["text"].split(" ").size()


func _merge_two_spans(span1: Dictionary, span2: Dictionary) -> Dictionary:
	# For change operations, span["text"] is NEW text (visible content)
	# The meta contains OLD text (and NEW text for change ops). When merging change spans, 
	# we need to merge OLD texts and NEW texts separately.
	var merged_new_text: String = span1["text"] + " " + span2["text"]
	var parts1: PackedStringArray = span1["meta"].split(DELIMITER, 3)
	var parts2: PackedStringArray = span2["meta"].split(DELIMITER, 3)
	
	var operation: String = span1["operation"]
	var current_word_idx: int = int(parts1[1])
	var merged_meta: String = ""
	
	if operation == "change":
		# For change ops, meta is: operation|index|base64_old|base64_new
		# We need to merge both old and new texts
		var old_text1: String = Marshalls.base64_to_utf8(parts1[2]) if parts1.size() > 2 else ""
		var new_text1: String = Marshalls.base64_to_utf8(parts1[3]) if parts1.size() > 3 else ""
		var old_text2: String = Marshalls.base64_to_utf8(parts2[2]) if parts2.size() > 2 else ""
		var new_text2: String = Marshalls.base64_to_utf8(parts2[3]) if parts2.size() > 3 else ""
		var merged_old_text: String = old_text1 + " " + old_text2
		var merged_new_text_for_meta: String = new_text1 + " " + new_text2
		merged_meta = operation + DELIMITER + str(current_word_idx) + DELIMITER + _encode_text(merged_old_text) + DELIMITER + _encode_text(merged_new_text_for_meta)
	else:
		# For insert/delete, meta is: operation|index|base64_text
		# We only need to merge the text (which is the same for both old and new in meta)
		var text1: String = Marshalls.base64_to_utf8(parts1[2]) if parts1.size() > 2 else ""
		var text2: String = Marshalls.base64_to_utf8(parts2[2]) if parts2.size() > 2 else ""
		var merged_text: String = text1 + " " + text2
		merged_meta = operation + DELIMITER + str(current_word_idx) + DELIMITER + _encode_text(merged_text)

	return {
		"start": span1["start"],
		"end": span2["end"],
		"operation": operation,
		"meta": merged_meta,
		"bgcolor": span1["bgcolor"],
		"text": merged_new_text
	}


func _rebuild_bbcode_from_spans(bbcode: String, merged_spans: Array[Dictionary]) -> String:
	var final_result: Array[String] = []
	var last_pos: int = 0
	var length: int = bbcode.length()

	for merged_span: Dictionary in merged_spans:
		# Add text before this span
		if merged_span["start"] > last_pos:
			final_result.append(bbcode.substr(last_pos, merged_span["start"] - last_pos))

		# Reconstruct the span with proper BBCode structure
		var bgcolor: String = _get_bgcolor(merged_span["operation"])
		final_result.append("[url=" + merged_span["meta"] + "][bgcolor=" + bgcolor + "]" + merged_span["text"] + "[/bgcolor][/url]")

		last_pos = merged_span["end"]

	# Add remaining text
	if last_pos < length:
		final_result.append(bbcode.substr(last_pos))

	return "".join(final_result)

# Word-level diff for grammar corrections
func calculate_diff(old_text: String, new_text: String, include_url_meta: bool = true) -> String:
	var old_words: PackedStringArray = old_text.split(" ")
	var new_words: PackedStringArray = new_text.split(" ")

	var result: Array[String] = []
	var pos: Dictionary = {"i": 0, "j": 0}

	while pos["i"] < old_words.size() or pos["j"] < new_words.size():
		_process_diff_step(result, old_words, new_words, pos, include_url_meta)

	var bbcode_result: String = " ".join(result)
	if include_url_meta:
		return _merge_adjacent_spans(bbcode_result)
	else:
		return bbcode_result


## Process one step of the diff algorithm
func _process_diff_step(result: Array[String], old_words: Array[String], new_words: Array[String], pos: Dictionary, include_url_meta: bool) -> void:
	var i: int = pos.get("i", 0)
	var j: int = pos.get("j", 0)

	# Find how many consecutive words match starting from current position
	var match_count: int = _find_match_count(old_words, new_words, i, j)

	# Add matching words
	if match_count > 0:
		_process_matched_words(result, old_words, i, match_count)
		pos["i"] = i + match_count
		pos["j"] = j + match_count
		return

	# Find best matching word ahead
	var max_look_ahead: int = min(MAX_LOOK_AHEAD, old_words.size() - i, new_words.size() - j)
	var best_match_idx: int = _find_best_match_ahead(old_words, new_words, i, j, max_look_ahead)

	if best_match_idx != -1:
		# Find the corresponding old index for the match at new_words[best_match_idx]
		var best_match_old_idx: int = i
		for look_ahead_old: int in range(0, max_look_ahead + 1):
			var old_idx: int = i + look_ahead_old
			if old_idx < old_words.size() and old_words[old_idx] == new_words[best_match_idx]:
				best_match_old_idx = old_idx
				break
		_process_changes_with_match(result, old_words, new_words, i, j, best_match_old_idx, best_match_idx, include_url_meta)
		pos["i"] = best_match_old_idx
		pos["j"] = best_match_idx
		return

	# No match found ahead, just mark current word as changed
	_process_single_word_change(result, old_words, new_words, i, j, include_url_meta)
	_result_advance_positions(old_words, new_words, i, j, pos)


func _result_advance_positions(old_words: Array, new_words: Array, i: int, j: int, pos: Dictionary) -> void:
	if i < old_words.size() and j < new_words.size():
		pos["i"] = i + 1
		pos["j"] = j + 1
	elif j < new_words.size():
		pos["i"] = i
		pos["j"] = j + 1
	elif i < old_words.size():
		pos["i"] = i + 1
		pos["j"] = j


## Helper functions for calculate_diff

func _find_match_count(old_words: Array[String], new_words: Array[String], i: int, j: int) -> int:
	var match_count: int = 0
	while i + match_count < old_words.size() and j + match_count < new_words.size() and old_words[i + match_count] == new_words[j + match_count]:
		match_count += 1
	return match_count


func _process_matched_words(result: Array[String], old_words: Array[String], start_idx: int, count: int) -> void:
	for k: int in range(count):
		result.append(old_words[start_idx + k])


func _find_best_match_ahead(old_words: Array[String], new_words: Array[String], i: int, j: int, max_look_ahead: int) -> int:
	# Look for any matching word within look-ahead range in both arrays
	# Check up to max_look_ahead words ahead in both old and new
	var max_old: int = min(i + max_look_ahead, old_words.size() - 1)
	var max_new: int = min(j + max_look_ahead, new_words.size() - 1)
	for old_idx: int in range(i, max_old + 1):
		for new_idx: int in range(j, max_new + 1):
			if old_words[old_idx] == new_words[new_idx]:
				return new_idx
	return -1





func _process_changes_with_match(result: Array[String], old_words: Array[String], new_words: Array[String], start_i: int, start_j: int, best_match_old_idx: int, best_match_idx: int, include_url_meta: bool) -> void:
	# Collect unmatched old and new words
	var old_changes: Array[String] = []
	var i: int = start_i
	while i < best_match_old_idx:
		old_changes.append(old_words[i])
		i += 1

	var new_changes: Array[String] = []
	var j: int = start_j
	while j < best_match_idx:
		new_changes.append(new_words[j])
		j += 1

	# If we have both deletions and insertions, show as orange changes
	if old_changes.size() > 0 and new_changes.size() > 0:
		_process_change_block(result, old_changes, new_changes, start_i, "change", include_url_meta)
	elif old_changes.size() > 0:
		# Only deletions
		_process_deletions(result, old_changes, start_i, include_url_meta)
	elif new_changes.size() > 0:
		# Only insertions
		_process_insertions(result, new_changes, start_i, include_url_meta)


func _process_single_word_change(result: Array[String], old_words: Array[String], new_words: Array[String], i: int, j: int, include_url_meta: bool) -> void:
	if i < old_words.size() and j < new_words.size():
		# This is a deletion+insertion pair at same position - show as orange
		var bgcolor: String = _get_bgcolor("change")
		var old_word: String = old_words[i]
		var new_word: String = new_words[j]
		if include_url_meta:
			result.append("[url=change" + DELIMITER + str(i) + DELIMITER + _encode_text(old_word) + DELIMITER + _encode_text(new_word) + "][bgcolor=" + bgcolor + "]" + new_word + "[/bgcolor][/url]")
		else:
			result.append("[bgcolor=" + bgcolor + "]" + new_word + "[/bgcolor]")
	elif j < new_words.size():
		var bgcolor: String = _get_bgcolor("insert")
		var word: String = new_words[j]
		if include_url_meta:
			result.append("[url=insert" + DELIMITER + str(i) + DELIMITER + _encode_text(word) + "][bgcolor=" + bgcolor + "]" + word + "[/bgcolor][/url]")
		else:
			result.append("[bgcolor=" + bgcolor + "]" + word + "[/bgcolor]")
	elif i < old_words.size():
		var bgcolor: String = _get_bgcolor("delete")
		var word: String = old_words[i]
		if include_url_meta:
			result.append("[url=delete" + DELIMITER + str(i) + DELIMITER + _encode_text(word) + "][bgcolor=" + bgcolor + "]" + word + "[/bgcolor][/url]")
		else:
			result.append("[bgcolor=" + bgcolor + "]" + word + "[/bgcolor]")


func _process_change_block(result: Array[String], old_changes: Array[String], new_changes: Array[String], word_idx: int, operation: String, include_url_meta: bool) -> void:
	var old_text: String = " ".join(old_changes)
	var new_text: String = " ".join(new_changes)
	var bgcolor: String = _get_bgcolor(operation)
	if include_url_meta:
		# For change operations, encode both old and new text
		if operation == "change":
			result.append("[url=" + operation + DELIMITER + str(word_idx) + DELIMITER + _encode_text(old_text) + DELIMITER + _encode_text(new_text) + "][bgcolor=" + bgcolor + "]" + new_text + "[/bgcolor][/url]")
		else:
			result.append("[url=" + operation + DELIMITER + str(word_idx) + DELIMITER + _encode_text(old_text) + "][bgcolor=" + bgcolor + "]" + new_text + "[/bgcolor][/url]")
	else:
		result.append("[bgcolor=" + bgcolor + "]" + new_text + "[/bgcolor]")


func _process_deletions(result: Array[String], deletions: Array[String], word_idx: int, include_url_meta: bool) -> void:
	if deletions.size() > 0:
		var merged_deletions: String = " ".join(deletions)
		var bgcolor: String = _get_bgcolor("delete")
		if include_url_meta:
			result.append("[url=delete" + DELIMITER + str(word_idx) + DELIMITER + _encode_text(merged_deletions) + "][bgcolor=" + bgcolor + "]" + merged_deletions + "[/bgcolor][/url]")
		else:
			result.append("[bgcolor=" + bgcolor + "]" + merged_deletions + "[/bgcolor]")


func _process_insertions(result: Array[String], insertions: Array[String], word_idx: int, include_url_meta: bool) -> void:
	if insertions.size() > 0:
		var merged_insertions: String = " ".join(insertions)
		var bgcolor: String = _get_bgcolor("insert")
		if include_url_meta:
			result.append("[url=insert" + DELIMITER + str(word_idx) + DELIMITER + _encode_text(merged_insertions) + "][bgcolor=" + bgcolor + "]" + merged_insertions + "[/bgcolor][/url]")
		else:
			result.append("[bgcolor=" + bgcolor + "]" + merged_insertions + "[/bgcolor]")
