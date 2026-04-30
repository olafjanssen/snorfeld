# Diff Utility for GDScript
# Utility class for calculating and formatting text differences between two strings.
# Uses diff-match-patch algorithm to perform semantic diff operations.

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

# Main diff utility functions
func calculate_diff(old_text: String, new_text: String, show_deletions: bool = true, show_insertions: bool = true) -> String:
	"""
	Calculates the difference between two text strings and returns a formatted result.

	Args:
		old_text: The original text
		new_text: The new text
		show_deletions: Whether to show deleted text (default: true)
		show_insertions: Whether to show inserted text (default: true)

	Returns:
		A formatted string showing the differences with visual indicators
	"""
	var diffs = _diff_main(old_text, new_text)
	diffs = _diff_cleanup_semantic(diffs)
	var merged_diffs = _merge_split_words(diffs)
	return _format_diff_output(merged_diffs, show_deletions, show_insertions)

func get_intermediate_animated_diff(formatted_diff: String, current_index: int) -> String:
	"""
	Gets an intermediate animation frame for the diff animation.

	Args:
		formatted_diff: The formatted diff string
		current_index: The current animation step index

	Returns:
		The diff string at the specified animation step
	"""
	var output = []
	var segments = _split_diff_segments(formatted_diff)
	var animation_step_counter = 0

	for segment in segments:
		if segment == "":
			continue

		if segment.begins_with("[s]"):
			var content = segment.substr(3, segment.length() - 7)  # from "[s]content[/s]"
			var block_steps = content.length()

			if animation_step_counter >= current_index:
				output.append(segment)
			else:
				var steps_into_block = current_index - animation_step_counter
				var chars_to_remove = min(steps_into_block, block_steps)
				var chars_to_keep = block_steps - chars_to_remove

				if chars_to_keep > 0:
					output.append("[s]" + content.substr(0, chars_to_keep) + "[/s]")
					output.append("█")
			animation_step_counter += block_steps

		elif segment.begins_with("[b]"):
			var content = segment.substr(3, segment.length() - 7)  # from "[b]content[/b]"
			var block_steps = content.length()

			if animation_step_counter < current_index:
				var steps_into_block = current_index - animation_step_counter
				var chars_to_add = min(steps_into_block, block_steps)

				if chars_to_add > 0:
					output.append("[b]" + content.substr(0, chars_to_add) + "[/b]")
					if chars_to_add < block_steps:
						output.append("█")
			animation_step_counter += block_steps

		else:  # Equal text
			var block_steps = segment.length()

			if animation_step_counter >= current_index:
				output.append(segment)
			else:
				var steps_into_block = current_index - animation_step_counter
				output.append(segment.substr(0, min(steps_into_block, block_steps)))
				if steps_into_block < block_steps:
					output.append("█")
				output.append(segment.substr(min(steps_into_block, block_steps), block_steps - min(steps_into_block, block_steps)))
			animation_step_counter += block_steps

	return "".join(output)

func get_animation_steps(formatted_diff: String) -> int:
	"""
	Calculates the total number of animation steps needed for the diff animation.

	Args:
		formatted_diff: The formatted diff string

	Returns:
		The total number of animation steps
	"""
	var segments = _split_diff_segments(formatted_diff)
	var total_steps = 0

	for segment in segments:
		if segment == "":
			continue

		if segment.begins_with("[s]"):
			total_steps += segment.substr(3, segment.length() - 7).length()
		elif segment.begins_with("[b]"):
			total_steps += segment.substr(3, segment.length() - 7).length()
		else:  # Equal text
			total_steps += segment.length()

	return total_steps

func _format_diff_output(word_level_diffs: Array, show_deletions: bool = true, show_insertions: bool = true) -> String:
	"""
	Formats the diff output with visual indicators for different operations.
	Allows control over which types of changes to show.

	Args:
		word_level_diffs: The word-level diffs to format
		show_deletions: Whether to show deleted text (default: true)
		show_insertions: Whether to show inserted text (default: true)

	Returns:
		A formatted string with visual indicators for selected change types
	"""
	var diff_builder = []

	for diff in word_level_diffs:
		match diff.operation:
			Operation.DELETE:
				if show_deletions:
					diff_builder.append("[s]" + diff.text + "[/s]")
			Operation.INSERT:
				if show_insertions:
					diff_builder.append("[b]" + diff.text + "[/b]")
			Operation.EQUAL:
				diff_builder.append(diff.text)

	return "".join(diff_builder).strip_edges()

func _is_space_char(c: String) -> bool:
	"""
	Checks if a character is a whitespace character.

	Args:
		c: The character to check

	Returns:
		true if the character is whitespace, false otherwise
	"""
	return c == ' ' or c == '\t' or c == '\n' or c == '\r'

func _find_first_whitespace(s: String) -> int:
	"""
	Finds the first whitespace character in a string.

	Args:
		s: The string to search

	Returns:
		The index of the first whitespace character, or -1 if not found
	"""
	for i in range(s.length()):
		var char = s[i]
		if _is_space_char(char):
			return i
	return -1

func _merge_split_words(diffs: Array) -> Array:
	"""
	Merges split words in the diff to improve readability.

	Args:
		diffs: The diffs to process

	Returns:
		The merged diffs
	"""
	var merged_diffs = []
	var buffer = []

	for i in range(diffs.size()):
		var current_diff = diffs[i]

		if current_diff.operation == Operation.EQUAL:
			if buffer.size() > 0 and current_diff.text.length() > 0 and not _is_space_char(current_diff.text[0]):
				var last_buffered_diff = buffer[buffer.size() - 1]
				if last_buffered_diff.text.length() > 0 and not _is_space_char(last_buffered_diff.text[last_buffered_diff.text.length() - 1]):
					var common_suffix = current_diff.text
					var split_point = _find_first_whitespace(common_suffix)

					var word_part = ""
					var rest = ""
					if split_point != -1:
						word_part = common_suffix.substr(0, split_point)
						rest = common_suffix.substr(split_point)
					else:
						word_part = common_suffix
						rest = ""

					for diff in buffer:
						merged_diffs.append(Diff.new(diff.operation, diff.text + word_part))
					buffer.clear()

					if rest != "":
						merged_diffs.append(Diff.new(Operation.EQUAL, rest))
					continue

			if buffer.size() > 0:
				merged_diffs.append_array(buffer)
				buffer.clear()
			merged_diffs.append(current_diff)

		else:  # INSERT or DELETE
			buffer.append(current_diff)

	if buffer.size() > 0:
		merged_diffs.append_array(buffer)

	return merged_diffs

# Diff Match Patch implementation (simplified version for GDScript)

func _diff_main(text1: String, text2: String) -> Array:
	"""
	Find the differences between two texts.

	Args:
		text1: Old string to be diffed
		text2: New string to be diffed

	Returns:
		Array of Diff objects
	"""
	# Check for equality
	if text1 == text2:
		if text1.length() > 0:
			return [Diff.new(Operation.EQUAL, text1)]
		return []

	# Trim the common prefix
	var common_length = _diff_common_prefix(text1, text2)
	var common_prefix = text1.substr(0, common_length)
	var text1_remaining = text1.substr(common_length)
	var text2_remaining = text2.substr(common_length)

	# Trim the common suffix
	common_length = _diff_common_suffix(text1_remaining, text2_remaining)
	var common_suffix = text1_remaining.substr(text1_remaining.length() - common_length)
	text1_remaining = text1_remaining.substr(0, text1_remaining.length() - common_length)
	text2_remaining = text2_remaining.substr(0, text2_remaining.length() - common_length)

	var diffs = _diff_compute(text1_remaining, text2_remaining)

	# Restore the prefix and suffix
	if common_prefix.length() > 0:
		diffs.insert(0, Diff.new(Operation.EQUAL, common_prefix))
	if common_suffix.length() > 0:
		diffs.append(Diff.new(Operation.EQUAL, common_suffix))

	return _diff_cleanup_merge(diffs)

func _diff_common_prefix(text1: String, text2: String) -> int:
	"""
	Determine the common prefix of two strings.

	Args:
		text1: First string
		text2: Second string

	Returns:
		The number of characters common to the start of each string
	"""
	var n = min(text1.length(), text2.length())
	for i in range(n):
		if text1[i] != text2[i]:
			return i
	return n

func _diff_common_suffix(text1: String, text2: String) -> int:
	"""
	Determine the common suffix of two strings.

	Args:
		text1: First string
		text2: Second string

	Returns:
		The number of characters common to the end of each string
	"""
	var text1_length = text1.length()
	var text2_length = text2.length()
	var n = min(text1_length, text2_length)
	for i in range(n):
		if text1[text1_length - i - 1] != text2[text2_length - i - 1]:
			return i
	return n

func _diff_compute(text1: String, text2: String) -> Array:
	"""
	Compute the diff between two texts using the Myers algorithm.

	Args:
		text1: Old string to be diffed
		text2: New string to be diffed

	Returns:
		Array of Diff objects
	"""
	if text1.length() == 0:
		return [Diff.new(Operation.INSERT, text2)]
	if text2.length() == 0:
		return [Diff.new(Operation.DELETE, text1)]

	var text1_length = text1.length()
	var text2_length = text2.length()
	var max_d = text1_length + text2_length
	var v = {}
	v[1] = 0
	v[-1] = 0
	var x = 0
	var y = 0

	for d in range(max_d + 1):
		for k in range(-d, d + 1, 2):
			# Check if the required keys exist before comparing
			var v_k_minus_1 = v.get(k - 1, -1)
			var v_k_plus_1 = v.get(k + 1, -1)
			var down = (k == -d or (k != d and v_k_minus_1 != -1 and v_k_plus_1 != -1 and v_k_minus_1 < v_k_plus_1))
			var k_prev = k - 1 if down else k + 1
			var x_prev = v.get(k_prev, 0)
			var y_prev = x_prev - k_prev

			if down:
				x = x_prev
			else:
				x = x_prev + 1
			y = x - k

			# Follow the diagonal (with bounds checking)
			while x < text1_length and y < text2_length and x >= 0 and y >= 0 and text1[x] == text2[y]:
				x += 1
				y += 1

			v[k] = x

			if x >= text1_length and y >= text2_length:
				# Reconstruct the diff
				var diffs = []
				var x_current = text1_length
				var y_current = text2_length

				for d_rev in range(d, -1, -1):
					var k_rev = x_current - y_current
					# Check if the required keys exist before comparing
					var v_k_rev_minus_1 = v.get(k_rev - 1, -1)
					var v_k_rev_plus_1 = v.get(k_rev + 1, -1)
					var down_rev = (k_rev == -d_rev or (k_rev != d_rev and v_k_rev_minus_1 != -1 and v_k_rev_plus_1 != -1 and v_k_rev_minus_1 < v_k_rev_plus_1))
					var k_prev_rev = k_rev - 1 if down_rev else k_rev + 1
					var x_prev_rev = v.get(k_prev_rev, 0)
					var y_prev_rev = x_prev_rev - k_prev_rev

					if down_rev:
						# This is a deletion
						diffs.insert(0, Diff.new(Operation.DELETE, text1.substr(x_prev_rev, x_current - x_prev_rev)))
					else:
						# This is an insertion
						diffs.insert(0, Diff.new(Operation.INSERT, text2.substr(y_prev_rev, y_current - y_prev_rev)))

					x_current = x_prev_rev
					y_current = y_prev_rev

				return diffs

	return [Diff.new(Operation.DELETE, text1), Diff.new(Operation.INSERT, text2)]

func _diff_cleanup_semantic(diffs: Array) -> Array:
	"""
	Cleanup a diff array to make it more readable.

	Args:
		diffs: Array of Diff objects

	Returns:
		Cleaned up array of Diff objects
	"""
	var changes = false
	var equalities = []  # Stack of indices where equalities are found
	var last_equality = ""
	var pointer = 0  # Index of current position
	var length_insertions1 = 0
	var length_deletions1 = 0
	var length_insertions2 = 0
	var length_deletions2 = 0

	while pointer < diffs.size():
		if diffs[pointer].operation == Operation.EQUAL:
			equalities.append(pointer)
			length_insertions1 = length_insertions2
			length_deletions1 = length_deletions2
			length_insertions2 = 0
			length_deletions2 = 0
			last_equality = diffs[pointer].text
		else:
			if diffs[pointer].operation == Operation.INSERT:
				length_insertions2 += diffs[pointer].text.length()
			else:
				length_deletions2 += diffs[pointer].text.length()

			# Factor out any common prefix
			if last_equality.length() > 0 and diffs[pointer].text.begins_with(last_equality):
				var common_length = _diff_common_prefix(last_equality, diffs[pointer].text)
				if common_length >= last_equality.length() / 2 or common_length >= diffs[pointer].text.length() / 2:
					# Push the common prefix to the previous equality
					if equalities.size() > 0:
						var prev_index = equalities[equalities.size() - 1]
						diffs[prev_index].text += diffs[pointer].text.substr(0, common_length)
						diffs[pointer].text = diffs[pointer].text.substr(common_length)

						# If the previous diff is now empty, remove it
						if diffs[prev_index - 1].text == "":
							diffs.remove_at(prev_index - 1)
							equalities.remove(equalities.size() - 1)  # Adjust stack
							pointer=pointer-1

						# If the current diff is now empty, remove it and adjust pointer
						if diffs[pointer].text == "":
							diffs.remove_at(pointer)
							pointer=pointer-1
						changes = true

			# Factor out any common suffix
			if last_equality.length() > 0 and diffs[pointer].text.ends_with(last_equality):
				var common_length = _diff_common_suffix(last_equality, diffs[pointer].text)
				if common_length >= last_equality.length() / 2 or common_length >= diffs[pointer].text.length() / 2:
					# Push the common suffix to the next equality
					diffs[pointer].text = diffs[pointer].text.substr(0, diffs[pointer].text.length() - common_length)
					diffs.insert(pointer + 1, Diff.new(Operation.EQUAL, last_equality.substr(last_equality.length() - common_length)))
					changes = true

		pointer += 1

	if changes:
		return _diff_cleanup_merge(diffs)
	return diffs

func _diff_cleanup_merge(diffs: Array) -> Array:
	"""
	Merge adjacent equalities in a diff array.

	Args:
		diffs: Array of Diff objects

	Returns:
		Merged array of Diff objects
	"""
	var changes = false
	var pointer = 1

	while pointer < diffs.size():
		if diffs[pointer - 1].operation == Operation.EQUAL and diffs[pointer].operation == Operation.EQUAL:
			diffs[pointer - 1].text += diffs[pointer].text
			diffs.remove_at(pointer)
			changes = true
		else:
			pointer += 1

	if changes:
		return _diff_cleanup_merge(diffs)  # Recursively merge
	return diffs

func _split_diff_segments(formatted_diff: String) -> Array:
	"""
	Splits a formatted diff string into segments without using regex.
	Handles [s]text[/s] and [b]text[/b] tags.
	"""
	var segments = []
	var current_pos = 0
	var length = formatted_diff.length()

	while current_pos < length:
		# Look for [s] tag
		var s_start = formatted_diff.find("[s]", current_pos)
		var b_start = formatted_diff.find("[b]", current_pos)

		# Find the earliest tag
		var next_tag_pos = min(s_start, b_start)
		if s_start == -1:
			next_tag_pos = b_start
		if b_start == -1:
			next_tag_pos = s_start

		# If no more tags found, add remaining text and break
		if next_tag_pos == -1:
			if current_pos < length:
				segments.append(formatted_diff.substr(current_pos))
			break

		# Add text before the tag
		if next_tag_pos > current_pos:
			segments.append(formatted_diff.substr(current_pos, next_tag_pos - current_pos))

		# Handle the tag
		if next_tag_pos == s_start:
			# Find matching [/s]
			var s_end = formatted_diff.find("[/s]", s_start)
			if s_end != -1:
				segments.append(formatted_diff.substr(s_start, s_end - s_start + 4))  # Include [/s]
				current_pos = s_end + 4
			else:
				# No matching tag, add remaining and break
				segments.append(formatted_diff.substr(s_start))
				break
		else:  # b_start
			# Find matching [/b]
			var b_end = formatted_diff.find("[/b]", b_start)
			if b_end != -1:
				segments.append(formatted_diff.substr(b_start, b_end - b_start + 4))  # Include [/b]
				current_pos = b_end + 4
			else:
				# No matching tag, add remaining and break
				segments.append(formatted_diff.substr(b_start))
				break

	return segments
