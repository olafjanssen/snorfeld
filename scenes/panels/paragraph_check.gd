extends Control

@onready var Correction: PaneledRichTextLabel = $TabContainer/Grammar/MarginContainer/VBoxContainer/Correction
@onready var GrammarExplanation: Label = $TabContainer/Grammar/MarginContainer/VBoxContainer/GrammarExplanation
@onready var Enhancement: PaneledRichTextLabel = $TabContainer/Style/MarginContainer/VBoxContainer/Enhancement
@onready var StyleExplanation: Label = $TabContainer/Style/MarginContainer/VBoxContainer/StyleExplanation
@onready var Suggestion: PaneledRichTextLabel = $TabContainer/Structure/MarginContainer/VBoxContainer/Suggestion
@onready var StructureExplanation: Label = $TabContainer/Structure/MarginContainer/VBoxContainer/StructureExplanation
@onready var DefinitionValue: Label = $TabContainer/Dictionary/MarginContainer/VBoxContainer/DefinitionValue
@onready var SynonymsList: PaneledRichTextLabel = $TabContainer/Dictionary/MarginContainer/VBoxContainer/SynonymsList
@onready var WordValue: Label = $TabContainer/Dictionary/MarginContainer/VBoxContainer/WordValue

# Stats tab references
@onready var HeaderLabel: Label = $TabContainer/Stats/MarginContainer/VBoxContainer/HeaderLabel
@onready var ChapterAvgLabel: Label = $TabContainer/Stats/MarginContainer/VBoxContainer/ChapterAvgLabel
@onready var ChapterAvgBar: ProgressBar = $TabContainer/Stats/MarginContainer/VBoxContainer/ChapterAvgBar
@onready var PairwiseLabel: Label = $TabContainer/Stats/MarginContainer/VBoxContainer/PairwiseLabel
@onready var PairwiseBar: ProgressBar = $TabContainer/Stats/MarginContainer/VBoxContainer/PairwiseBar
@onready var SlidingWindowLabel: Label = $TabContainer/Stats/MarginContainer/VBoxContainer/SlidingWindowLabel
@onready var SlidingWindowBar: ProgressBar = $TabContainer/Stats/MarginContainer/VBoxContainer/SlidingWindowBar
@onready var FileStats: Label = $TabContainer/Stats/MarginContainer/VBoxContainer/FileStats
@onready var FileStatsLabel: Label = $TabContainer/Stats/MarginContainer/VBoxContainer/FileStatsLabel

const PULSE_EASE: float = -4.0
const COHESIVE_THRESHOLD := 0.5
var icon_text : String = "[pulse freq=1.0 color=#ffffff40 ease=%s]✲[/pulse] " % PULSE_EASE


# Store current context for patch application
var current_file_path: String = ""
var current_line_number: int = -1
var current_paragraph_text: String = ""
var current_paragraph_hash: String = ""

# Store texts for diff display
var _corrected_text: String = ""
var _enhanced_text: String = ""
var _suggestion_text: String = ""
var bgcolor: String = ""

# Store cache data for all analysis types
var _grammar_cache_data: Dictionary = {}
var _style_cache_data: Dictionary = {}
var _structure_cache_data: Dictionary = {}
var _cohesion_cache_data: Dictionary = {}
var _file_cohesion_stats: Dictionary = {}
var _dictionary_cache_data: Dictionary = {}

# Store selected word for dictionary lookup
var _selected_word: String = ""
var _selected_word_index: int = -1

func _ready():
	EventBus.paragraph_selected.connect(_on_paragraph_selected)
	EventBus.diff_span_clicked.connect(_on_diff_span_clicked)
	EventBus.theme_changed.connect(_on_theme_changed)
	EventBus.analysis_task_completed.connect(_on_analysis_task_completed)
	EventBus.editor_content_changed.connect(_on_editor_content_changed)
	EventBus.word_selected.connect(_on_word_selected)
	# Connect to dictionary word_info_ready signal
	AnalysisManager.DictionaryService.word_info_ready.connect(_on_word_info_ready)
	# Connect to tab changed signal
	$TabContainer.tab_changed.connect(_on_tab_changed)

	bgcolor = get_theme_color("diff_change_bg", "DiffCalculator").to_html()

# gdlint:ignore-function:long-function
func _update_diff_displays() -> void:
	# Update all tabs based on their cached data
	# Grammar tab
	if _corrected_text != "":
		if current_paragraph_text != _corrected_text:
			var diff_utility_grammar: DiffUtility = DiffUtility.new()
			diff_utility_grammar.set_control(self)
			Correction.set_text(diff_utility_grammar.calculate_diff(current_paragraph_text, _corrected_text))
		else:
			Correction.set_text("No grammar and spelling suggestions.")
	else:
		Correction.set_text("No grammar and spelling suggestions.")

	# Style tab
	if _enhanced_text != "":
		if current_paragraph_text != _enhanced_text:
			var diff_utility_style: DiffUtility = DiffUtility.new()
			diff_utility_style.set_control(self)
			Enhancement.set_text(diff_utility_style.calculate_diff(current_paragraph_text, _enhanced_text))
		else:
			Enhancement.set_text("No stylistic suggestions.")
	else:
		Enhancement.set_text("No stylistic suggestions.")

	# Structure tab
	if _suggestion_text != "":
		var diff_utility_structure: DiffUtility = DiffUtility.new()
		diff_utility_structure.set_control(self)
		Suggestion.set_text(diff_utility_structure.calculate_diff(current_paragraph_text, _suggestion_text))
	else:
		Suggestion.set_text("No structural suggestions.")

func _on_theme_changed() -> void:
	_update_diff_displays()

func _update_dictionary_display() -> void:
	# Update dictionary tab with word info
	if _dictionary_cache_data.is_empty():
		WordValue.text = _selected_word if _selected_word != "" else "No word selected"
		DefinitionValue.text = ""
		SynonymsList.set_text("")
		return

	WordValue.text = _selected_word
	DefinitionValue.text = _dictionary_cache_data.get("definition", "")

	# Build synonyms list with clickable links
	var synonyms: Array = _dictionary_cache_data.get("synonyms", [])
	if synonyms.size() > 0:
		# Find the word in the line (with punctuation)
		var word_info: Dictionary = _find_word_in_line()
		if word_info.is_empty():
			SynonymsList.set_text("No synonyms available")
			return
		var word_index: int = word_info["word_index"]
		var actual_word: String = word_info["actual_word"]
		var synonyms_text: String = "[ul]"
		for syn in synonyms:
			if syn is Dictionary:
				var synonym_word: String = syn.get("word", "")
				var difference: String = syn.get("difference", "")
				# Create clickable meta for this synonym
				var meta: String = _create_synonym_meta(word_index, _selected_word, synonym_word)
				synonyms_text += "[url=" + meta + "][bgcolor=" + bgcolor + "]" + synonym_word + "[/bgcolor][/url]: " + difference + "\n"
		synonyms_text += "[/ul]"
		SynonymsList.set_text(synonyms_text)
	else:
		SynonymsList.set_text("No synonyms available")

func _find_word_in_line() -> Dictionary:
	# Get the actual word at the stored word_index with its punctuation
	# Returns {word_index: int, actual_word: String} or empty dict if not found

	if _selected_word_index < 0 or current_paragraph_text == "":
		return {}

	var words: PackedStringArray = current_paragraph_text.split(" ")
	if _selected_word_index >= words.size():
		return {}

	return {"word_index": _selected_word_index, "actual_word": words[_selected_word_index]}

func _is_punctuation(character: String) -> bool:
	var code: int = ord(character)
	# ASCII punctuation
	return (code >= 33 and code <= 47) or (code >= 58 and code <= 64) or (code >= 91 and code <= 96) or (code >= 123 and code <= 126)

func _create_synonym_meta(word_index: int, old_word: String, new_word: String) -> String:
	# Format: change|word_index|base64(old_word)|base64(new_word)
	# Preserve trailing punctuation from old_word on new_word
	# e.g., if old_word is "Okay," and new_word is "Alright", we want "Alright,"
	var new_word_with_punct: String = new_word
	# Get trailing punctuation from old_word
	var old_trailing: String = ""
	var old_clean: String = old_word
	while old_clean.length() > 0 and _is_punctuation(old_clean.substr(old_clean.length() - 1, 1)):
		old_trailing = old_clean.substr(old_clean.length() - 1, 1) + old_trailing
		old_clean = old_clean.substr(0, old_clean.length() - 1)
	# Get leading punctuation from old_word
	var old_leading: String = ""
	while old_clean.length() > 0 and old_clean.length() < old_word.length() and _is_punctuation(old_clean.substr(0, 1)):
		old_leading += old_clean.substr(0, 1)
		old_clean = old_clean.substr(1)
	new_word_with_punct = old_leading + new_word + old_trailing

	var encoded_old: String = Marshalls.utf8_to_base64(old_word)
	var encoded_new: String = Marshalls.utf8_to_base64(new_word_with_punct)
	return "change|%d|%s|%s" % [word_index, encoded_old, encoded_new]

func _on_analysis_task_completed(service_type: String, _remaining: int) -> void:
	if service_type not in ['grammar','style','structure','cohesion','dictionary']:
		return

	# When a cache task completes, refresh the display for the current paragraph
	# This handles the case where we requested analysis for a specific tab
	if current_paragraph_hash != "" and current_file_path != "":
		# Reload the cache for the current paragraph
		_grammar_cache_data = AnalysisManager.GrammarService.get_grammar_cache(current_paragraph_hash)
		_style_cache_data = AnalysisManager.StyleService.get_style_cache(current_paragraph_hash)
		_structure_cache_data = AnalysisManager.StructureService.get_structure_cache(current_paragraph_hash)
		_cohesion_cache_data = AnalysisManager.CohesionService.get_cohesion(current_paragraph_hash, current_file_path)
		_file_cohesion_stats = AnalysisManager.CohesionService.get_file_cohesion_stats(current_file_path)

		# Update display for the current active tab
		var active_tab: int = $TabContainer.get_current_tab()
		_update_display_for_active_tab(active_tab)

func _on_word_info_ready(word: String, info: Dictionary) -> void:
	# Only respond if the result is still relevant data
	if word != _selected_word:
		return
		
	# Store the word info for display
	_dictionary_cache_data = info
	_selected_word = word
	# If dictionary tab is active, update display
	if $TabContainer.get_current_tab() == 4:
		_update_dictionary_display()

func _on_diff_span_clicked(operation: String, word_index: int, old_text: String, new_text: String):
	# old_text and new_text are already properly set by clickable_label.gd
	# Emit signal with line_number - editor will verify via BookService
	CommandBus.apply_diff_patch.emit(
		current_file_path,
		current_line_number,
		operation,
		word_index,
		old_text,
		new_text
	)

func _on_editor_content_changed(path: String, _content: String):
	if current_file_path != path:
		return

	# Get latest paragraph text that we use with stale analysis data
	var para_data: Dictionary = BookService.get_paragraph_at_line(current_file_path, current_line_number)
	current_paragraph_text = para_data.get("text", "")
	_update_diff_displays()

func _on_word_selected(file_path: String, line_number: int, word_index: int, word: String):
	# Store the selected word and its index
	_selected_word = word
	_selected_word_index = word_index
	current_file_path = file_path
	current_line_number = line_number

	# Get the paragraph containing the word for context
	var para_data: Dictionary = BookService.get_paragraph_at_line(file_path, line_number)
	current_paragraph_hash = para_data.get("hash", "")
	current_paragraph_text = para_data.get("text", "")

	# Clear old dictionary cache
	_dictionary_cache_data = {}

	# Fetch word info with context from the paragraph
	# First check cache, then request async fetch
	var cached_info: Dictionary = AnalysisManager.DictionaryService.get_cached_word_info(word, current_paragraph_text)
	if not cached_info.is_empty():
		# Use cached data immediately
		_dictionary_cache_data = cached_info
		_on_word_info_ready(word, cached_info)
	else:
		# Request async fetch
		AnalysisManager.DictionaryService.get_word_info(word, current_paragraph_text)

func _on_paragraph_selected(file_path: String, line_number: int):
	current_file_path = file_path
	current_line_number = line_number

	# Get paragraph from BookService
	var para_data: Dictionary = BookService.get_paragraph_at_line(file_path, line_number)
	current_paragraph_hash = para_data.get("hash", "")
	current_paragraph_text = para_data.get("text", "")

	# Initialize text variables
	_corrected_text = ""
	_enhanced_text = ""
	_suggestion_text = ""
	_dictionary_cache_data = {}
	_selected_word = ""

	# Load ALL analysis types for this paragraph
	_grammar_cache_data = AnalysisManager.GrammarService.get_grammar_cache(current_paragraph_hash)
	_style_cache_data = AnalysisManager.StyleService.get_style_cache(current_paragraph_hash)
	_structure_cache_data = AnalysisManager.StructureService.get_structure_cache(current_paragraph_hash)
	_cohesion_cache_data = AnalysisManager.CohesionService.get_cohesion(current_paragraph_hash, current_file_path)
	_file_cohesion_stats = AnalysisManager.CohesionService.get_file_cohesion_stats(current_file_path)

	# Get the active tab
	var active_tab: int = $TabContainer.get_current_tab()

	# Update display for active tab
	_update_display_for_active_tab(active_tab)


func _on_tab_changed(tab_index: int):
	# When user switches tabs, update the display with the appropriate cache data
	_update_display_for_active_tab(tab_index)


# gdlint:ignore-function:long-function
func _update_display_for_active_tab(tab_index: int):
	# Clear all explanation texts first
	GrammarExplanation.text = ""
	StyleExplanation.text = ""
	StructureExplanation.text = ""

	# Initialize text variables
	_corrected_text = ""
	_enhanced_text = ""
	_suggestion_text = ""

	match tab_index:
		0:  # Grammar tab
			if _grammar_cache_data:
				_corrected_text = _grammar_cache_data.get("corrected", "")
				GrammarExplanation.text = _grammar_cache_data.get("explanation", "")
			else:
				Correction.set_text(icon_text + "Generating analysis...")
				CommandBus.priority_analysis.emit("grammar", current_file_path, {"line_number": current_line_number})
				return
		1:  # Style tab
			if _style_cache_data:
				_enhanced_text = _style_cache_data.get("enhanced", "")
				StyleExplanation.text = _style_cache_data.get("explanation", "")
			else:
				Correction.set_text(icon_text + "Generating analysis...")
				CommandBus.priority_analysis.emit("style", current_file_path, {"line_number": current_line_number})
				return
		2:  # Structure tab
			if _structure_cache_data:
				_suggestion_text = _structure_cache_data.get("suggestion", "")
				StructureExplanation.text = _structure_cache_data.get("explanation", "")
			else:
				Correction.set_text(icon_text + "Generating analysis...")
				CommandBus.priority_analysis.emit("structure", current_file_path, {"line_number": current_line_number})
				return
		3:  # Stats tab
			_update_stats_tab()
			return
		4:  # Dictionary tab
			_update_dictionary_display()
			return

	_update_diff_displays()


func _update_stats_tab() -> void:
	# Check if we have the basic data
	if current_paragraph_hash == "" or current_file_path == "":
		HeaderLabel.text = "No paragraph selected"
		ChapterAvgLabel.text = "Chapter Average: -"
		ChapterAvgBar.value = 0
		PairwiseLabel.text = "Pairwise All: -"
		PairwiseBar.value = 0
		SlidingWindowLabel.text = "Sliding Window: -"
		SlidingWindowBar.value = 0
		FileStats.text = "Select a paragraph to see cohesion metrics"
		return

	if _cohesion_cache_data.is_empty():
		# No cohesion data yet, request analysis
		HeaderLabel.text = "Generating paragraph cohesion..."
		ChapterAvgLabel.text = "Chapter Average:"
		ChapterAvgBar.value = 0
		PairwiseLabel.text = "Pairwise All:"
		PairwiseBar.value = 0
		SlidingWindowLabel.text = "Sliding Window:"
		SlidingWindowBar.value = 0
		FileStats.text = "Cohesion statistics will appear here"
		CommandBus.priority_analysis.emit("cohesion", current_file_path, {"paragraph_hash": current_paragraph_hash, "file_path": current_file_path, "line_number": current_line_number})
		return

	HeaderLabel.text = "Paragraph Cohesion Metrics:"

	# Get all three scores from paragraph cohesion cache
	var scores: Dictionary = _cohesion_cache_data.get("scores", {})
	var chapter_avg_score: float = scores.get("chapter_average", 0.0)
	var pairwise_score: float = scores.get("pairwise_all", 0.0)
	var sliding_window_score: float = scores.get("sliding_window", 0.0)
	var threshold: float = _cohesion_cache_data.get("threshold", COHESIVE_THRESHOLD)

	# Update progress bars with scores (0.0 - 1.0 maps to 0 - 100%)
	ChapterAvgBar.value = chapter_avg_score * 100.0
	PairwiseBar.value = pairwise_score * 100.0
	SlidingWindowBar.value = sliding_window_score * 100.0

	# Update labels with scores formatted to 3 decimal places
	ChapterAvgLabel.text = "Chapter Average: %.3f" % chapter_avg_score
	PairwiseLabel.text = "Pairwise All: %.3f" % pairwise_score
	SlidingWindowLabel.text = "Sliding Window: %.3f" % sliding_window_score

	# Set colors based on whether each score is above threshold
	# Chapter Average color
	if chapter_avg_score >= threshold:
		ChapterAvgBar.self_modulate = Color(0, 1, 0)  # Green
		ChapterAvgLabel.add_theme_color_override("font_color", Color(0, 1, 0))
	else:
		ChapterAvgBar.self_modulate = Color(1, 0.5, 0)  # Orange/red
		ChapterAvgLabel.add_theme_color_override("font_color", Color(1, 0.5, 0))

	# Pairwise color
	if pairwise_score >= threshold:
		PairwiseBar.self_modulate = Color(0, 1, 0)
		PairwiseLabel.add_theme_color_override("font_color", Color(0, 1, 0))
	else:
		PairwiseBar.self_modulate = Color(1, 0.5, 0)
		PairwiseLabel.add_theme_color_override("font_color", Color(1, 0.5, 0))

	# Sliding Window color
	if sliding_window_score >= threshold:
		SlidingWindowBar.self_modulate = Color(0, 1, 0)
		SlidingWindowLabel.add_theme_color_override("font_color", Color(0, 1, 0))
	else:
		SlidingWindowBar.self_modulate = Color(1, 0.5, 0)
		SlidingWindowLabel.add_theme_color_override("font_color", Color(1, 0.5, 0))

	# Update file/chapter statistics
	if not _file_cohesion_stats.is_empty() and _file_cohesion_stats.get("status") != "no_data":
		var file_threshold: float = _file_cohesion_stats.get("threshold", COHESIVE_THRESHOLD)
		var avg: float = _file_cohesion_stats.get("average_score", 0.0)
		var total: int = _file_cohesion_stats.get("total_paragraphs", 0)
		var cohesive: int = _file_cohesion_stats.get("cohesive_count", 0)
		var outliers: int = _file_cohesion_stats.get("outlier_count", 0)
		FileStats.text = "Average: %.3f | %d/%d cohesive | %d outliers (threshold: %.2f)" % [avg, cohesive, total, outliers, file_threshold]
	else:
		FileStats.text = "No file statistics available"
