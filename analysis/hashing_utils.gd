class_name HashingUtils
extends RefCounted
## Utility functions for hashing

## Create an MD5 hash from a string
static func hash_md5(input: String) -> String:
	var hash_ctx := HashingContext.new()
	hash_ctx.start(HashingContext.HASH_MD5)
	hash_ctx.update(input.to_utf8_buffer())
	var hash_bytes := hash_ctx.finish()
	return hash_bytes.hex_encode()

## Calculate similarity between two strings (0-100)
## Used for fuzzy matching in character/object services
static func calculate_similarity(str1: String, str2: String) -> int:
	const PERFECT_MATCH: int = 100
	const PARTIAL_MATCH: int = 90
	const BASE_MULTIPLIER: int = 100

	var s1: String = str1.to_lower()
	var s2: String = str2.to_lower()

	if s1 == s2:
		return PERFECT_MATCH

	if s1.find(s2) != -1 or s2.find(s1) != -1:
		return PARTIAL_MATCH

	var words1: Array = s1.split(" ", false)
	var words2: Array = s2.split(" ", false)
	var common_count: int = 0

	for word1 in words1:
		for word2 in words2:
			if word1 == word2 and word1.length() > 2:
				common_count += 1
				break

	var total_words: int = words1.size() + words2.size()
	if total_words == 0:
		return 0

	return int((common_count * 2.0 / total_words) * BASE_MULTIPLIER)
