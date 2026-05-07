# Diff Utility for GDScript
# Word-level diff for grammar corrections.

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

# URL encoding constants
const URL_ENCODE_SPACE := "%20"
const URL_ENCODE_COLON := "%3A"
const URL_ENCODE_PIPE := "%7C"

# Look-ahead limit for matching words in diff algorithm
const MAX_LOOK_AHEAD := 5

# BBCode tag lengths
const URL_TAG_OPEN_LENGTH := 5  # Length of "[url="
const URL_TAG_CLOSE_LENGTH := 6  # Length of "[/url]"

# Encode text for URL meta: replace spaces, colons, and pipe delimiter
func _encode_text(text: String) -> String:
	return text.replace(" ", URL_ENCODE_SPACE).replace(":", URL_ENCODE_COLON).replace(DELIMITER, URL_ENCODE_PIPE)

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

	# parts[1] = "word_indexDELIMITERencoded_text"
	var subparts1: PackedStringArray = parts1[1].split(DELIMITER, 1)
	var subparts2: PackedStringArray = parts2[1].split(DELIMITER, 1)

	if subparts1.size() < 1 or subparts2.size() < 1:
		return false

	var word_idx1: int = int(subparts1[0])
	var word_idx2: int = int(subparts2[0])

	return word_idx2 == word_idx1 + span1["text"].split(" ").size()


func _merge_two_spans(span1: Dictionary, span2: Dictionary) -> Dictionary:
	var merged_text: String = span1["text"] + " " + span2["text"]
	var parts1: PackedStringArray = span1["meta"].split(DELIMITER, 2)
	var subparts1: PackedStringArray = parts1[1].split(DELIMITER, 1)
	var current_word_idx: int = int(subparts1[0])
	var merged_meta: String = span1["operation"] + DELIMITER + str(current_word_idx) + DELIMITER + _encode_text(merged_text)

	return {
		"start": span1["start"],
		"end": span2["end"],
		"operation": span1["operation"],
		"meta": merged_meta,
		"bgcolor": span1["bgcolor"],
		"text": merged_text
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
func calculate_diff(old_text: String, new_text: String, show_deletions: bool = true, show_insertions: bool = true) -> String:
	var old_words: PackedStringArray = old_text.split(" ")
	var new_words: PackedStringArray = new_text.split(" ")

	var result: Array[String] = []
	var i: int = 0
	var j: int = 0

	while i < old_words.size() or j < new_words.size():
		# Find how many consecutive words match starting from current position
		var match_count: int = _find_match_count(old_words, new_words, i, j)

		# Add matching words
		if match_count > 0:
			_process_matched_words(result, old_words, i, match_count)
			i += match_count
			j += match_count
			continue

		# Find best matching word ahead (look-ahead up to MAX_LOOK_AHEAD words)
		var best_match_idx: int = -1
		var best_match_old_idx: int = -1
		var max_look_ahead: int = min(MAX_LOOK_AHEAD, old_words.size() - i, new_words.size() - j)

		best_match_idx = _find_best_match_ahead(old_words, new_words, i, j, max_look_ahead)
		if best_match_idx != -1:
			best_match_old_idx = _get_old_index_for_match(old_words, new_words, i, j, max_look_ahead)

		# If we found a match ahead, add the unmatched words as changes and skip to the match
		if best_match_idx != -1:
			_process_changes_with_match(result, old_words, new_words, i, j, best_match_old_idx, best_match_idx, show_deletions, show_insertions)
			i = best_match_old_idx
			j = best_match_idx
		else:
			# No match found ahead, just mark current word as changed
			_process_single_word_change(result, old_words, new_words, i, j, show_deletions, show_insertions)
			if i < old_words.size() and j < new_words.size():
				i += 1
				j += 1
			elif j < new_words.size():
				j += 1
			elif i < old_words.size():
				i += 1

	var bbcode_result: String = " ".join(result)

	# Post-process to merge adjacent spans of the same type
	var merged: String = _merge_adjacent_spans(bbcode_result)
	return merged


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
	# Look for old word matching new word ahead
	for look_ahead: int in range(1, max_look_ahead + 1):
		if i + look_ahead - 1 < old_words.size() and old_words[i + look_ahead - 1] == new_words[j]:
			return j
		if j + look_ahead - 1 < new_words.size() and old_words[i] == new_words[j + look_ahead - 1]:
			return j + look_ahead - 1
	return -1


func _get_old_index_for_match(old_words: Array[String], new_words: Array[String], i: int, j: int, max_look_ahead: int) -> int:
	# Find the corresponding old index for the match
	for look_ahead: int in range(1, max_look_ahead + 1):
		if i + look_ahead - 1 < old_words.size() and old_words[i + look_ahead - 1] == new_words[j]:
			return i + look_ahead - 1
		if j + look_ahead - 1 < new_words.size() and old_words[i] == new_words[j + look_ahead - 1]:
			return i
	return i


func _process_changes_with_match(result: Array[String], old_words: Array[String], new_words: Array[String], start_i: int, start_j: int, best_match_old_idx: int, best_match_idx: int, show_deletions: bool, show_insertions: bool) -> void:
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

	# If we have equal number of deletions and insertions, show as orange changes
	if old_changes.size() == new_changes.size() and old_changes.size() > 0:
		_process_change_block(result, new_changes, start_i, "change", show_insertions)
	else:
		# Different counts - show deletions and insertions separately
		_process_deletions(result, old_changes, start_i, show_deletions)
		_process_insertions(result, new_changes, start_j, show_insertions)


func _process_single_word_change(result: Array[String], old_words: Array[String], new_words: Array[String], i: int, j: int, show_deletions: bool, show_insertions: bool) -> void:
	if i < old_words.size() and j < new_words.size():
		# This is a deletion+insertion pair at same position - show as orange
		if show_insertions:
			var bgcolor: String = _get_bgcolor("change")
			result.append("[url=change" + DELIMITER + str(i) + DELIMITER + _encode_text(new_words[j]) + "][bgcolor=" + bgcolor + "]" + new_words[j] + "[/bgcolor][/url]")
		else:
			result.append(new_words[j])
	elif j < new_words.size():
		if show_insertions:
			var bgcolor: String = _get_bgcolor("insert")
			result.append("[url=insert" + DELIMITER + str(j) + DELIMITER + _encode_text(new_words[j]) + "][bgcolor=" + bgcolor + "]" + new_words[j] + "[/bgcolor][/url]")
		else:
			result.append(new_words[j])
	elif i < old_words.size():
		if show_deletions:
			var bgcolor: String = _get_bgcolor("delete")
			result.append("[url=delete" + DELIMITER + str(i) + DELIMITER + _encode_text(old_words[i]) + "][bgcolor=" + bgcolor + "]" + old_words[i] + "[/bgcolor][/url]")
		else:
			result.append(old_words[i])


func _process_change_block(result: Array[String], changes: Array[String], word_idx: int, operation: String, show: bool) -> void:
	if show:
		var merged_text: String = " ".join(changes)
		var bgcolor: String = _get_bgcolor(operation)
		result.append("[url=" + operation + DELIMITER + str(word_idx) + DELIMITER + _encode_text(merged_text) + "][bgcolor=" + bgcolor + "]" + merged_text + "[/bgcolor][/url]")
	else:
		for word in changes:
			result.append(word)


func _process_deletions(result: Array[String], deletions: Array[String], word_idx: int, show: bool) -> void:
	if show and deletions.size() > 0:
		var merged_deletions: String = " ".join(deletions)
		var bgcolor: String = _get_bgcolor("delete")
		result.append("[url=delete" + DELIMITER + str(word_idx) + DELIMITER + _encode_text(merged_deletions) + "][bgcolor=" + bgcolor + "]" + merged_deletions + "[/bgcolor][/url]")
	else:
		for word in deletions:
			result.append(word)


func _process_insertions(result: Array[String], insertions: Array[String], word_idx: int, show: bool) -> void:
	if show and insertions.size() > 0:
		var merged_insertions: String = " ".join(insertions)
		var bgcolor: String = _get_bgcolor("insert")
		result.append("[url=insert" + DELIMITER + str(word_idx) + DELIMITER + _encode_text(merged_insertions) + "][bgcolor=" + bgcolor + "]" + merged_insertions + "[/bgcolor][/url]")
	else:
		for word in insertions:
			result.append(word)
