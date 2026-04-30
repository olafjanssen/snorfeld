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
				for k in range(old_changes.size()):
					if show_insertions:
						result.append("[bgcolor=orange]" + new_changes[k] + "[/bgcolor]")
					else:
						result.append(new_changes[k])
			else:
				# Different counts - show deletions and insertions separately
				for word in old_changes:
					if show_deletions:
						result.append("[bgcolor=red]" + word + "[/bgcolor]")
					else:
						result.append(word)
				for word in new_changes:
					if show_insertions:
						result.append("[bgcolor=green]" + word + "[/bgcolor]")
					else:
						result.append(word)
		else:
			# No match found ahead, just mark current word as changed
			if i < old_words.size() and j < new_words.size():
				# This is a deletion+insertion pair at same position - show as orange
				if show_insertions:
					result.append("[bgcolor=orange]" + new_words[j] + "[/bgcolor]")
				else:
					result.append(new_words[j])
				i += 1
				j += 1
			elif j < new_words.size():
				if show_insertions:
					result.append("[bgcolor=green]" + new_words[j] + "[/bgcolor]")
				else:
					result.append(new_words[j])
				j += 1
			elif i < old_words.size():
				if show_deletions:
					result.append("[bgcolor=red]" + old_words[i] + "[/bgcolor]")
				else:
					result.append(old_words[i])
				i += 1

	return " ".join(result)
