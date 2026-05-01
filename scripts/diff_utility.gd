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

# Encode text for URL meta: replace spaces, colons, and pipe delimiter
func _encode_text(text: String) -> String:
	return text.replace(" ", "%20").replace(":", "%3A").replace("|", "%7C")

# Get the bgcolor for an operation type
func _get_bgcolor(operation: String) -> String:
	match operation:
		"delete": return "red"
		"insert": return "green"
		"change": return "orange"
	return "white"

# Helper to merge adjacent spans of the same type
func _merge_adjacent_spans(bbcode: String) -> String:
	# Parse the BBCode and find adjacent spans of the same type
	# Format: [url=operationDELIMITERword_indexDELIMITERencoded_text][bgcolor=X]text[/bgcolor][/url]
	var spans := []
	var i := 0
	var length := bbcode.length()

	while i < length:
		if bbcode.substr(i, 5) == "[url=":
			# Found a span start
			var url_end := bbcode.find("]", i)
			if url_end == -1:
				break

			# Extract meta: operationDELIMITERword_indexDELIMITERencoded_text
			var meta := bbcode.substr(i + 5, url_end - (i + 5))
			var meta_parts := meta.split(DELIMITER, 2)
			if meta_parts.size() < 2:
				break

			var operation := meta_parts[0]
			var bgcolor := _get_bgcolor(operation)

			# Find the bgcolor tag
			var bgcolor_start := bbcode.find("[bgcolor=" + bgcolor + "]", url_end)
			if bgcolor_start == -1:
				break

			var bgcolor_end := bbcode.find("[/bgcolor]", bgcolor_start)
			if bgcolor_end == -1:
				break

			var text_start := bgcolor_start + ("[bgcolor=" + bgcolor + "]").length()
			var text_content := bbcode.substr(text_start, bgcolor_end - text_start)
			var url_close := bbcode.find("[/url]", bgcolor_end)
			if url_close == -1:
				break
			var url_close_end := url_close + 6

			spans.append({
				"start": i,
				"end": url_close_end,
				"operation": operation,
				"meta": meta,
				"bgcolor": bgcolor,
				"text": text_content
			})

			i = url_close_end
		else:
			i += 1

	# Now merge consecutive spans of the same type
	var merged_spans := []
	var has_current := false
	var current_merge: Dictionary

	for span in spans:
		if not has_current:
			current_merge = span
			has_current = true
		elif current_merge["operation"] == span["operation"]:
			# Check if word indices are consecutive
			var current_meta_parts = current_merge["meta"].split(DELIMITER, 2)
			var span_meta_parts = span["meta"].split(DELIMITER, 2)

			# current_meta_parts[1] = "word_indexDELIMITERencoded_text"
			var current_parts = current_meta_parts[1].split(DELIMITER, 1)
			var span_parts = span_meta_parts[1].split(DELIMITER, 1)

			if current_parts.size() >= 1 and span_parts.size() >= 1:
				var current_word_idx := int(current_parts[0])
				var span_word_idx := int(span_parts[0])

				if span_word_idx == current_word_idx + current_merge["text"].split(" ").size():
					# Consecutive - merge them
					var merged_text = current_merge["text"] + " " + span["text"]
					var merged_meta = current_merge["operation"] + DELIMITER + str(current_word_idx) + DELIMITER + _encode_text(merged_text)
					current_merge["meta"] = merged_meta
					current_merge["text"] = merged_text
					current_merge["end"] = span["end"]
				else:
					# Not consecutive
					merged_spans.append(current_merge)
					current_merge = span
			else:
				merged_spans.append(current_merge)
				current_merge = span
		else:
			# Different operation
			merged_spans.append(current_merge)
			current_merge = span

	if has_current:
		merged_spans.append(current_merge)

	# Rebuild the BBCode with merged spans
	var final_result := []
	var last_pos := 0

	for merged_span in merged_spans:
		# Add text before this span
		if merged_span["start"] > last_pos:
			final_result.append(bbcode.substr(last_pos, merged_span["start"] - last_pos))

		# Reconstruct the span with proper BBCode structure
		var bgcolor := _get_bgcolor(merged_span["operation"])
		final_result.append("[url=" + merged_span["meta"] + "][bgcolor=" + bgcolor + "]" + merged_span["text"] + "[/bgcolor][/url]")

		last_pos = merged_span["end"]

	# Add remaining text
	if last_pos < length:
		final_result.append(bbcode.substr(last_pos))

	return "".join(final_result)

# Word-level diff for grammar corrections
func calculate_diff(old_text: String, new_text: String, show_deletions: bool = true, show_insertions: bool = true) -> String:
	var old_words := old_text.split(" ")
	var new_words := new_text.split(" ")

	var result := []
	var i := 0
	var j := 0

	while i < old_words.size() or j < new_words.size():
		# Find how many consecutive words match starting from current position
		var match_count := 0
		while i + match_count < old_words.size() and j + match_count < new_words.size() and old_words[i + match_count] == new_words[j + match_count]:
			match_count += 1

		# Add matching words
		if match_count > 0:
			for k in range(match_count):
				result.append(old_words[i + k])
			i += match_count
			j += match_count
			continue

		# Find best matching word ahead (look-ahead up to 5 words)
		var best_match_idx := -1
		var best_match_old_idx := -1
		var max_look_ahead : int = min(5, old_words.size() - i, new_words.size() - j)

		for look_ahead in range(1, max_look_ahead + 1):
			if i + look_ahead - 1 < old_words.size() and old_words[i + look_ahead - 1] == new_words[j]:
				best_match_idx = j
				best_match_old_idx = i + look_ahead - 1
				break
			if j + look_ahead - 1 < new_words.size() and old_words[i] == new_words[j + look_ahead - 1]:
				best_match_idx = j + look_ahead - 1
				best_match_old_idx = i
				break

		# If we found a match ahead, add the unmatched words as changes and skip to the match
		if best_match_idx != -1:
			# Collect unmatched old and new words
			var start_i := i
			var start_j := j
			var old_changes := []
			while i < best_match_old_idx:
				old_changes.append(old_words[i])
				i += 1

			var new_changes := []
			while j < best_match_idx:
				new_changes.append(new_words[j])
				j += 1

			# If we have equal number of deletions and insertions, show as orange changes
			if old_changes.size() == new_changes.size() and old_changes.size() > 0:
				# Merge consecutive changes of the same type
				var merged_text := " ".join(new_changes)
				if show_insertions:
					# Format: operation|word_index|encoded_text
					var word_idx = start_i
					result.append("[url=change" + DELIMITER + str(word_idx) + DELIMITER + _encode_text(merged_text) + "][bgcolor=orange]" + merged_text + "[/bgcolor][/url]")
				else:
					result.append(merged_text)
			else:
				# Different counts - show deletions and insertions separately
				# Merge consecutive deletions
				if show_deletions and old_changes.size() > 0:
					var merged_deletions := " ".join(old_changes)
					var word_idx = start_i
					result.append("[url=delete" + DELIMITER + str(word_idx) + DELIMITER + _encode_text(merged_deletions) + "][bgcolor=red]" + merged_deletions + "[/bgcolor][/url]")
				else:
					for word in old_changes:
						result.append(word)

				# Merge consecutive insertions
				if show_insertions and new_changes.size() > 0:
					var merged_insertions := " ".join(new_changes)
					var word_idx = start_j
					result.append("[url=insert" + DELIMITER + str(word_idx) + DELIMITER + _encode_text(merged_insertions) + "][bgcolor=green]" + merged_insertions + "[/bgcolor][/url]")
				else:
					for word in new_changes:
						result.append(word)
		else:
			# No match found ahead, just mark current word as changed
			if i < old_words.size() and j < new_words.size():
				# This is a deletion+insertion pair at same position - show as orange
				if show_insertions:
					result.append("[url=change" + DELIMITER + str(i) + DELIMITER + _encode_text(new_words[j]) + "][bgcolor=orange]" + new_words[j] + "[/bgcolor][/url]")
				else:
					result.append(new_words[j])
				i += 1
				j += 1
			elif j < new_words.size():
				if show_insertions:
					result.append("[url=insert" + DELIMITER + str(j) + DELIMITER + _encode_text(new_words[j]) + "][bgcolor=green]" + new_words[j] + "[/bgcolor][/url]")
				else:
					result.append(new_words[j])
				j += 1
			elif i < old_words.size():
				if show_deletions:
					result.append("[url=delete" + DELIMITER + str(i) + DELIMITER + _encode_text(old_words[i]) + "][bgcolor=red]" + old_words[i] + "[/bgcolor][/url]")
				else:
					result.append(old_words[i])
				i += 1

	var bbcode_result := " ".join(result)

	# Post-process to merge adjacent spans of the same type
	var merged := _merge_adjacent_spans(bbcode_result)
	return merged
