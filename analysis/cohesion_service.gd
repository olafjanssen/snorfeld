extends AnalysisService
# CohesionService - Computes paragraph cohesion statistics within chapters
# Uses embedding-based cosine similarity to measure how well paragraphs fit
# with their chapter, neighbors, or all other paragraphs

# gdlint:ignore-file:file-length,too-many-params,long-function,magic-number,long-line,high-complexity

# Cohesion method enum
enum CohesionMethod {
	CHAPTER_AVERAGE,    # Compare paragraph to average chapter embedding
	PAIRWISE_ALL,       # Compare paragraph to every other paragraph in chapter
	SLIDING_WINDOW      # Compare paragraph to neighboring paragraphs (k nearest)
}

# Cache filename for cohesion statistics
const COHESION_JSONL_FILENAME := "cohesion.jsonl"

# Default sliding window size (paragraphs before and after)
const DEFAULT_WINDOW_SIZE := 2

# Threshold for considering a paragraph cohesive (0.0 - 1.0)
const COHESIVE_THRESHOLD := 0.5

func _ready() -> void:
	# Configure service properties
	service_name = "cohesion"
	cache_subdir = "cohesion"
	cache_filename = COHESION_JSONL_FILENAME

	# Cohesion data doesn't need special encoding
	field_encoders = {}
	field_decoders = {}

	# Call parent _ready for base signal connections
	# This connects priority_analysis, delete_analysis_cache, project_loaded, project_unloaded
	super()

	# Connect service-specific signals
	CommandBus.start_analysis.connect(_on_start_analysis)
	EventBus.file_selected.connect(_on_file_selected)


## ============================================================================
## Configuration
## ============================================================================

# Get the cohesion method to use (configurable)
func get_cohesion_method() -> CohesionMethod:
	var method_str := AppConfig.get_cohesion_method()
	match method_str:
		"chapter_average":
			return CohesionMethod.CHAPTER_AVERAGE
		"pairwise_all":
			return CohesionMethod.PAIRWISE_ALL
		"sliding_window":
			return CohesionMethod.SLIDING_WINDOW
		_:
			return CohesionMethod.CHAPTER_AVERAGE

# Get the sliding window size
func get_window_size() -> int:
	return AppConfig.get_cohesion_window_size() if AppConfig.has_cohesion_window_size() else DEFAULT_WINDOW_SIZE


## ============================================================================
## Cache Key Management
## ============================================================================

# Override: Get cache key from payload
func _get_cache_key(payload: Dictionary) -> String:
	var paragraph_hash: String = payload.get("paragraph_hash", "")
	var file_path: String = payload.get("file_path", "")

	# Key format: file_path:paragraph_hash for per-paragraph cohesion
	if paragraph_hash != "" and file_path != "":
		return "%s:%s" % [file_path, paragraph_hash]
	return paragraph_hash


# Override: Get cache key from loaded data
func _get_cache_key_from_data(data: Dictionary) -> String:
	var paragraph_hash: String = data.get("paragraph_hash", "")
	var file_path: String = data.get("file_path", "")

	if paragraph_hash != "" and file_path != "":
		return "%s:%s" % [file_path, paragraph_hash]
	return paragraph_hash


## ============================================================================
## Cosine Similarity Utilities
## ============================================================================

# Compute cosine similarity between two embedding vectors
# Vectors should be PoolRealArray or Array of floats
static func cosine_similarity(vec_a: Array, vec_b: Array) -> float:
	if vec_a.size() == 0 or vec_b.size() == 0:
		return 0.0
	if vec_a.size() != vec_b.size():
		return 0.0

	var dot_product: float = 0.0
	var norm_a: float = 0.0
	var norm_b: float = 0.0

	for i in range(vec_a.size()):
		var a_val := float(vec_a[i])
		var b_val := float(vec_b[i])
		dot_product += a_val * b_val
		norm_a += a_val * a_val
		norm_b += b_val * b_val

	if norm_a == 0.0 or norm_b == 0.0:
		return 0.0

	var magnitude: float = sqrt(norm_a) * sqrt(norm_b)
	return dot_product / magnitude if magnitude != 0.0 else 0.0


# Compute average of multiple embedding vectors
static func average_embedding(embeddings: Array) -> Array:
	if embeddings.size() == 0:
		return []

	var first_vec: Array = embeddings[0]
	var dim: int = first_vec.size()
	var result: Array = []

	for i in range(dim):
		result.append(0.0)

	for vec in embeddings:
		if vec.size() != dim:
			continue
		for i in range(dim):
			result[i] += float(vec[i])

	# Divide by count
	for i in range(dim):
		result[i] /= float(embeddings.size())

	return result


## ============================================================================
## Analysis - Core Cohesion Computation
## ============================================================================

# Override: Analyze a paragraph and compute cohesion statistics
# Now computes ALL THREE methods for each paragraph
func _analyze(payload: Dictionary) -> Dictionary:
	var paragraph_hash: String = payload.get("paragraph_hash", "")
	var file_path: String = payload.get("file_path", "")

	if paragraph_hash == "" or file_path == "":
		push_error("[CohesionService] Missing paragraph_hash or file_path in payload")
		return {}

	# Get paragraph data
	var para_data: Dictionary = BookService.get_paragraph_by_hash(paragraph_hash)
	if para_data.is_empty():
		push_error("[CohesionService] Paragraph not found: %s" % paragraph_hash)
		return {}

	# Get file/chapter data
	var file_data: Dictionary = BookService.get_file(file_path)
	if file_data.is_empty():
		push_error("[CohesionService] File not found: %s" % file_path)
		return {}

	var chapter_id: String = para_data.get("chapter", "")
	var paragraphs_in_chapter: Array = []

	if chapter_id != "" and chapter_id != null:
		paragraphs_in_chapter = BookService.get_paragraphs_for_chapter(chapter_id)
	else:
		paragraphs_in_chapter = BookService.get_paragraphs_for_file(file_path)

	# Compute ALL THREE cohesion methods
	var chapter_avg_result := _compute_chapter_average_cohesion(file_path, paragraph_hash, paragraphs_in_chapter)
	var pairwise_result := _compute_pairwise_cohesion(file_path, paragraph_hash, paragraphs_in_chapter)
	var sliding_window_result := _compute_sliding_window_cohesion(file_path, paragraph_hash, paragraphs_in_chapter)

	# Extract scores from each method
	var chapter_avg_score: float = chapter_avg_result.get("cohesion_score", 0.0)
	var pairwise_score: float = pairwise_result.get("cohesion_score", 0.0)
	var sliding_window_score: float = sliding_window_result.get("cohesion_score", 0.0)

	# Create main result using chapter average as primary
	var main_result: Dictionary = _make_cohesion_result(
		paragraph_hash,
		file_path,
		chapter_avg_score,
		"computed",
		CohesionMethod.CHAPTER_AVERAGE,
		{
			"chapter_avg": chapter_avg_result.get("metadata", {}),
			"pairwise": pairwise_result.get("metadata", {}),
			"sliding_window": sliding_window_result.get("metadata", {})
		}
	)

	# Add all three scores to the result
	main_result["scores"] = {
		"chapter_average": chapter_avg_score,
		"pairwise_all": pairwise_score,
		"sliding_window": sliding_window_score
	}

	# Add individual method results
	main_result["chapter_average"] = chapter_avg_result
	main_result["pairwise_all"] = pairwise_result
	main_result["sliding_window"] = sliding_window_result

	return main_result


# gdlint:ignore-function:deep-nesting
# Compute cohesion by comparing paragraph to average chapter embedding
func _compute_chapter_average_cohesion(file_path: String, paragraph_hash: String, paragraph_ids: Array) -> Dictionary:
	# Get paragraph embedding
	var para_embedding: Dictionary = AnalysisManager.EmbeddingService.get_paragraph_embedding(paragraph_hash, file_path)
	if para_embedding.is_empty():
		push_warning("[CohesionService] No embedding for paragraph: %s" % paragraph_hash)
		return _make_default_cohesion_result(paragraph_hash, file_path, 0.0, "pending", CohesionMethod.CHAPTER_AVERAGE)

	var para_vec: Array = para_embedding.get("embedding", [])
	if para_vec.size() == 0:
		return _make_default_cohesion_result(paragraph_hash, file_path, 0.0, "no_embedding", CohesionMethod.CHAPTER_AVERAGE)

	# Get chapter embedding (average of all paragraphs)
	var chapter_embedding: Dictionary = AnalysisManager.EmbeddingService.get_chapter_embedding(file_path)

	if chapter_embedding.is_empty():
		# Compute average from paragraph embeddings
		var all_embeddings: Array = []
		for para_id in paragraph_ids:
			var p_hash: String = BookService.get_paragraph(para_id).get("hash", "")
			var p_emb: Dictionary = AnalysisManager.EmbeddingService.get_paragraph_embedding(p_hash, file_path)
			if not p_emb.is_empty():
				var p_vec: Array = p_emb.get("embedding", [])
				if p_vec.size() > 0:
					all_embeddings.append(p_vec)

		if all_embeddings.size() > 0:
			var avg_vec: Array = average_embedding(all_embeddings)
			var avg_similarity: float = cosine_similarity(para_vec, avg_vec)
			return _make_cohesion_result(paragraph_hash, file_path, avg_similarity, "computed", CohesionMethod.CHAPTER_AVERAGE, {"chapter_embedding": "computed_from_paragraphs"})
		else:
			return _make_default_cohesion_result(paragraph_hash, file_path, 0.0, "no_embeddings", CohesionMethod.CHAPTER_AVERAGE)

	var chapter_vec: Array = chapter_embedding.get("embedding", [])
	if chapter_vec.size() == 0:
		return _make_default_cohesion_result(paragraph_hash, file_path, 0.0, "invalid_chapter_embedding", CohesionMethod.CHAPTER_AVERAGE)

	var similarity: float = cosine_similarity(para_vec, chapter_vec)
	return _make_cohesion_result(paragraph_hash, file_path, similarity, "cached", CohesionMethod.CHAPTER_AVERAGE, {})


# Compute cohesion by comparing paragraph to every other paragraph
func _compute_pairwise_cohesion(file_path: String, paragraph_hash: String, paragraph_ids: Array) -> Dictionary:
	# Get target paragraph embedding
	var target_embedding: Dictionary = AnalysisManager.EmbeddingService.get_paragraph_embedding(paragraph_hash, file_path)
	if target_embedding.is_empty():
		return _make_default_cohesion_result(paragraph_hash, file_path, 0.0, "no_target_embedding", CohesionMethod.PAIRWISE_ALL)

	var target_vec: Array = target_embedding.get("embedding", [])
	if target_vec.size() == 0:
		return _make_default_cohesion_result(paragraph_hash, file_path, 0.0, "empty_target_embedding", CohesionMethod.PAIRWISE_ALL)

	var similarities: Array = []
	var valid_count: int = 0

	for para_id in paragraph_ids:
		var p_hash: String = BookService.get_paragraph(para_id).get("hash", "")
		# Skip self-comparison
		if p_hash == paragraph_hash:
			continue

		var p_embedding: Dictionary = AnalysisManager.EmbeddingService.get_paragraph_embedding(p_hash, file_path)
		if p_embedding.is_empty():
			continue

		var p_vec: Array = p_embedding.get("embedding", [])
		if p_vec.size() == 0:
			continue

		if p_vec.size() != target_vec.size():
			continue

		var sim: float = cosine_similarity(target_vec, p_vec)
		similarities.append(sim)
		valid_count += 1

	if valid_count == 0:
		return _make_default_cohesion_result(paragraph_hash, file_path, 0.0, "no_valid_paragraphs", CohesionMethod.PAIRWISE_ALL)

	# Compute statistics
	var avg_similarity: float = 0.0
	var min_similarity: float = 1.0
	var max_similarity: float = 0.0

	for sim in similarities:
		avg_similarity += sim
		min_similarity = min(min_similarity, sim)
		max_similarity = max(max_similarity, sim)

	avg_similarity /= float(similarities.size())

	# Count how many paragraphs are above threshold
	var cohesive_count: int = 0
	for sim in similarities:
		if sim >= COHESIVE_THRESHOLD:
			cohesive_count += 1

	var cohesive_ratio: float = float(cohesive_count) / float(similarities.size())

	var metadata: Dictionary = {
		"pairwise_count": valid_count,
		"average_similarity": avg_similarity,
		"min_similarity": min_similarity,
		"max_similarity": max_similarity,
		"cohesive_ratio": cohesive_ratio,
		"cohesive_count": cohesive_count
	}

	return _make_cohesion_result(paragraph_hash, file_path, avg_similarity, "computed", CohesionMethod.PAIRWISE_ALL, metadata)


# Compute cohesion by comparing paragraph to neighboring paragraphs (sliding window)
func _compute_sliding_window_cohesion(file_path: String, paragraph_hash: String, paragraph_ids: Array) -> Dictionary:
	var window_size: int = get_window_size()

	# Get target paragraph embedding
	var target_embedding: Dictionary = AnalysisManager.EmbeddingService.get_paragraph_embedding(paragraph_hash, file_path)
	if target_embedding.is_empty():
		return _make_default_cohesion_result(paragraph_hash, file_path, 0.0, "no_target_embedding", CohesionMethod.SLIDING_WINDOW)

	var target_vec: Array = target_embedding.get("embedding", [])
	if target_vec.size() == 0:
		return _make_default_cohesion_result(paragraph_hash, file_path, 0.0, "empty_target_embedding", CohesionMethod.SLIDING_WINDOW)

	# Find index of target paragraph in the list
	var target_index: int = -1
	for i in range(paragraph_ids.size()):
		var para_id: String = paragraph_ids[i]
		var p_hash: String = BookService.get_paragraph(para_id).get("hash", "")
		if p_hash == paragraph_hash:
			target_index = i
			break

	if target_index == -1:
		return _make_default_cohesion_result(paragraph_hash, file_path, 0.0, "paragraph_not_found", CohesionMethod.SLIDING_WINDOW)

	# Get neighboring paragraphs within window
	var start_index: int = max(0, target_index - window_size)
	var end_index: int = min(paragraph_ids.size() - 1, target_index + window_size)

	var neighbor_similarities: Array = []
	var neighbor_count: int = 0

	for i in range(start_index, end_index + 1):
		# Skip self
		if i == target_index:
			continue

		var para_id: String = paragraph_ids[i]
		var p_hash: String = BookService.get_paragraph(para_id).get("hash", "")

		var p_embedding: Dictionary = AnalysisManager.EmbeddingService.get_paragraph_embedding(p_hash, file_path)
		if p_embedding.is_empty():
			continue

		var p_vec: Array = p_embedding.get("embedding", [])
		if p_vec.size() == 0:
			continue

		if p_vec.size() != target_vec.size():
			continue

		var sim: float = cosine_similarity(target_vec, p_vec)
		neighbor_similarities.append(sim)
		neighbor_count += 1

	if neighbor_count == 0:
		return _make_default_cohesion_result(paragraph_hash, file_path, 0.0, "no_neighbors", CohesionMethod.SLIDING_WINDOW)

	# Compute average similarity to neighbors
	var avg_similarity: float = 0.0
	for sim in neighbor_similarities:
		avg_similarity += sim

	avg_similarity /= float(neighbor_similarities.size())

	# Also find min/max for additional context
	var min_similarity: float = 1.0
	var max_similarity: float = 0.0
	for sim in neighbor_similarities:
		min_similarity = min(min_similarity, sim)
		max_similarity = max(max_similarity, sim)

	var metadata: Dictionary = {
		"window_size": window_size,
		"neighbor_count": neighbor_count,
		"neighbors_checked": paragraph_ids.size() - 1,
		"min_similarity": min_similarity,
		"max_similarity": max_similarity
	}

	return _make_cohesion_result(paragraph_hash, file_path, avg_similarity, "computed", CohesionMethod.SLIDING_WINDOW, metadata)


# Create a default cohesion result
func _make_default_cohesion_result(paragraph_hash: String, file_path: String, score: float, reason: String, method: CohesionMethod) -> Dictionary:
	return {
		"paragraph_hash": paragraph_hash,
		"file_path": file_path,
		"cohesion_score": score,
		"method": method,
		"status": "default",
		"reason": reason,
		"is_cohesive": score >= COHESIVE_THRESHOLD,
		"cached_at": Time.get_unix_time_from_system(),
		"metadata": {}
	}


# Create a full cohesion result
func _make_cohesion_result(paragraph_hash: String, file_path: String, score: float, status: String, method: CohesionMethod, metadata: Dictionary) -> Dictionary:
	return {
		"paragraph_hash": paragraph_hash,
		"file_path": file_path,
		"cohesion_score": score,
		"method": method,
		"status": status,
		"is_cohesive": score >= COHESIVE_THRESHOLD,
		"threshold": COHESIVE_THRESHOLD,
		"cached_at": Time.get_unix_time_from_system(),
		"metadata": metadata
	}


## ============================================================================
## Queue Management
## ============================================================================

# Queue a paragraph for cohesion analysis
func queue_paragraph(paragraph_hash: String, file_path: String, priority: bool = false) -> void:
	var payload: Dictionary = {
		"paragraph_hash": paragraph_hash,
		"file_path": file_path
	}
	queue_task(payload, priority)


# Queue all paragraphs from a file for cohesion analysis
func queue_file_paragraphs(file_path: String) -> void:
	var file_data: Dictionary = BookService.get_file(file_path)
	if file_data.is_empty():
		return

	var para_ids: Array = BookService.get_paragraphs_for_file(file_path)
	for para_id in para_ids:
		var para_data: Dictionary = BookService.get_paragraph(para_id)
		var para_hash: String = para_data.get("hash", "")
		if para_hash != "":
			queue_paragraph(para_hash, file_path)


# Queue all paragraphs from all files
func queue_all_paragraphs() -> void:
	var all_files: Array = BookService.get_all_files()
	for file_path in all_files:
		queue_file_paragraphs(file_path)


# Queue all paragraphs for a specific chapter
func queue_chapter_paragraphs(chapter_id: String) -> void:
	var para_ids: Array = BookService.get_paragraphs_for_chapter(chapter_id)
	if para_ids.size() == 0:
		return

	# Get file path from first paragraph
	var first_para: Dictionary = BookService.get_paragraph(para_ids[0])
	var file_path: String = first_para.get("file", "")

	for para_id in para_ids:
		var para_data: Dictionary = BookService.get_paragraph(para_id)
		var para_hash: String = para_data.get("hash", "")
		if para_hash != "":
			queue_paragraph(para_hash, file_path)


## ============================================================================
## Public Getters
## ============================================================================

# Get cached cohesion analysis for a paragraph
func get_cohesion(paragraph_hash: String, file_path: String) -> Dictionary:
	var key := "%s:%s" % [file_path, paragraph_hash]
	return memory_cache.get(key, {})


# Get all cohesion results for a file
func get_cohesion_for_file(file_path: String) -> Array:
	var results: Array = []
	for key in memory_cache:
		if key.begins_with(file_path + ":"):
			results.append(memory_cache[key])
	return results


# Get cohesion statistics for an entire file/chapter
func get_file_cohesion_stats(file_path: String) -> Dictionary:
	var all_cohesion: Array = get_cohesion_for_file(file_path)

	if all_cohesion.size() == 0:
		return {"status": "no_data", "file_path": file_path}

	var total: float = 0.0
	var count: int = 0
	var min_score: float = 1.0
	var max_score: float = 0.0
	var cohesive_count: int = 0

	for result in all_cohesion:
		var score: float = result.get("cohesion_score", 0.0)
		total += score
		count += 1
		min_score = min(min_score, score)
		max_score = max(max_score, score)
		if result.get("is_cohesive", false):
			cohesive_count += 1

	var avg_score: float = total / float(count) if count > 0 else 0.0
	var cohesive_ratio: float = float(cohesive_count) / float(count) if count > 0 else 0.0

	# Find potential outliers (below threshold)
	var outliers: Array = []
	for result in all_cohesion:
		if not result.get("is_cohesive", true):
			outliers.append({
				"paragraph_hash": result.get("paragraph_hash", ""),
				"score": result.get("cohesion_score", 0.0),
				"method": result.get("method", "unknown")
			})

	return {
		"status": "computed",
		"file_path": file_path,
		"average_score": avg_score,
		"min_score": min_score,
		"max_score": max_score,
		"cohesive_ratio": cohesive_ratio,
		"total_paragraphs": count,
		"cohesive_count": cohesive_count,
		"outlier_count": outliers.size(),
		"outliers": outliers,
		"threshold": COHESIVE_THRESHOLD
	}


## ============================================================================
## Signal Handlers
## ============================================================================

func _on_project_loaded(path: String) -> void:
	super(path)
	delete_cache()

func _on_start_analysis(service_type: String, scope: String) -> void:
	if service_type != "COHESION":
		return
	if scope == "project":
		queue_all_paragraphs()
	elif scope == "chapter":
		if current_file_path != "":
			queue_file_paragraphs(current_file_path)


func _on_file_selected(path: String) -> void:
	current_file_path = path


## ============================================================================
## Cleanup
## ============================================================================

# Override: Clean up cache entries that don't exist in the project anymore
func _cleanup_unused_cache_entries(cache_path: String, _project_path: String) -> int:
	# Get valid paragraph hashes from BookService
	var valid_paragraph_hashes: Array = BookService.get_all_paragraph_hashes()
	var valid_hash_set: Dictionary = {}
	for content_hash in valid_paragraph_hashes:
		valid_hash_set[content_hash] = true

	# Also get all file paths
	var valid_file_paths: Array = BookService.get_all_files()
	var valid_file_set: Dictionary = {}
	for fp in valid_file_paths:
		valid_file_set[fp] = true

	# Remove cache entries that don't have corresponding source
	var keys_to_remove: Array = []
	for key in memory_cache:
		# Key format: file_path:paragraph_hash
		var parts: Array = key.split(":")
		if parts.size() >= 2:
			var fp: String = parts[0]
			var para_hash: String = parts[1]
			if not valid_file_set.has(fp) or not valid_hash_set.has(para_hash):
				keys_to_remove.append(key)
				continue
			# Check if paragraph belongs to this file
			var para_data: Dictionary = BookService.get_paragraph_by_hash(para_hash)
			if para_data.is_empty() or para_data.get("file", "") != fp:
				keys_to_remove.append(key)
		else:
			# Key format doesn't match expected pattern, remove it
			keys_to_remove.append(key)

	# Remove from memory cache
	for key in keys_to_remove:
		memory_cache.erase(key)
		queued_keys.erase(key)

	# Rewrite the JSONL file
	_rewrite_jsonl_file(cache_path)

	return keys_to_remove.size()
