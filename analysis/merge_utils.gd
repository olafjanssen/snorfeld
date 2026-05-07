class_name MergeUtils
extends RefCounted
## Utility functions for merging data structures

## Merge two arrays, removing duplicates
static func merge_arrays_unique(existing: Array, new: Array) -> Array:
	var merged := []
	var seen: Dictionary = {}
	for item in existing:
		if not seen.has(item):
			merged.append(item)
			seen[item] = true
	for item in new:
		if not seen.has(item):
			merged.append(item)
			seen[item] = true
	return merged

## Merge two arrays, simply appending (may contain duplicates)
static func merge_arrays_append(existing: Array, new: Array) -> Array:
	var merged: Array = existing.duplicate()
	merged.append_array(new)
	return merged

## Merge two dictionaries (shallow merge, new values overwrite existing)
static func merge_dictionaries(existing: Dictionary, new: Dictionary) -> Dictionary:
	var merged: Dictionary = existing.duplicate()
	for key in new:
		merged[key] = new[key]
	return merged

## Concatenate two strings with a space separator
static func concat_strings(existing: String, new: String) -> String:
	if existing == "" and new == "":
		return ""
	elif existing == "":
		return new
	elif new == "":
		return existing
	else:
		return existing + " " + new

## Merge strategy types
enum MergeStrategy {
	REPLACE,           # New value completely replaces old value
	ARRAY_MERGE_UNIQUE, # Merge arrays, remove duplicates
	ARRAY_APPEND,      # Append to array (may have duplicates)
	DICT_MERGE,        # Merge dictionaries (new keys/values overwrite)
	CONCAT,            # Concatenate strings
	SKIP,              # Skip this field (keep existing)
}

## Apply a merge strategy to two values
static func apply_merge_strategy(strategy: MergeStrategy, existing, new) -> Variant:
	match strategy:
		MergeStrategy.REPLACE:
			return new

		MergeStrategy.ARRAY_MERGE_UNIQUE:
			if existing is Array and new is Array:
				return merge_arrays_unique(existing, new)
			return new

		MergeStrategy.ARRAY_APPEND:
			if existing is Array and new is Array:
				return merge_arrays_append(existing, new)
			return new

		MergeStrategy.DICT_MERGE:
			if existing is Dictionary and new is Dictionary:
				return merge_dictionaries(existing, new)
			return new

		MergeStrategy.CONCAT:
			if existing is String and new is String:
				return concat_strings(existing, new)
			return new

		MergeStrategy.SKIP:
			return existing

		_:
			return new

## Merge two dictionaries using a merge strategy dictionary
##
## @param existing The existing data dictionary
## @param new The new data dictionary
## @param merge_strategies Dictionary mapping field names to MergeStrategy values
## @return Merged dictionary
static func merge_data_with_strategies(
	existing: Dictionary,
	new: Dictionary,
	merge_strategies: Dictionary
) -> Dictionary:
	var result: Dictionary = existing.duplicate()

	for key in new:
		if not result.has(key):
			result[key] = new[key]
			continue

		var strategy: MergeStrategy = merge_strategies.get(key, MergeStrategy.REPLACE)
		result[key] = apply_merge_strategy(strategy, result[key], new[key])

	return result
