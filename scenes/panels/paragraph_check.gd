extends Control

@onready var Correction: PaneledRichTextLabel = $TabContainer/Grammar/MarginContainer/VBoxContainer/Correction
@onready var GrammarExplanation: Label = $TabContainer/Grammar/MarginContainer/VBoxContainer/GrammarExplanation
@onready var Enhancement: PaneledRichTextLabel = $TabContainer/Style/MarginContainer/VBoxContainer/Enhancement
@onready var StyleExplanation: Label = $TabContainer/Style/MarginContainer/VBoxContainer/StyleExplanation
@onready var Suggestion: PaneledRichTextLabel = $TabContainer/Structure/MarginContainer/VBoxContainer/Suggestion
@onready var StructureExplanation: Label = $TabContainer/Structure/MarginContainer/VBoxContainer/StructureExplanation
@onready var DefinitionValue: Label = $TabContainer/Dictionary/MarginContainer/VBoxContainer/DefinitionValue
@onready var PartOfSpeechValue: Label = $TabContainer/Dictionary/MarginContainer/VBoxContainer/PartOfSpeechValue
@onready var SynonymsList: PaneledRichTextLabel = $TabContainer/Dictionary/MarginContainer/VBoxContainer/SynonymsList

const PULSE_EASE: float = -4.0
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

# Store cache data for all analysis types
var _grammar_cache_data: Dictionary = {}
var _style_cache_data: Dictionary = {}
var _structure_cache_data: Dictionary = {}
var _dictionary_cache_data: Dictionary = {}

# Store selected word for dictionary lookup
var _selected_word: String = ""

func _ready():
	EventBus.paragraph_selected.connect(_on_paragraph_selected)
	EventBus.diff_span_clicked.connect(_on_diff_span_clicked)
	EventBus.theme_changed.connect(_on_theme_changed)
	EventBus.analysis_task_completed.connect(_on_analysis_task_completed)
	EventBus.editor_content_changed.connect(_on_editor_content_changed)
	# Connect to dictionary word_info_ready signal
	AnalysisManager.DictionaryService.word_info_ready.connect(_on_word_info_ready)
	# Connect to tab changed signal
	$TabContainer.tab_changed.connect(_on_tab_changed)

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
		DefinitionValue.text = "No word selected"
		PartOfSpeechValue.text = ""
		SynonymsList.set_text("")
		return

	DefinitionValue.text = _dictionary_cache_data.get("definition", "")
	PartOfSpeechValue.text = _dictionary_cache_data.get("part_of_speech", "")

	# Build synonyms list
	var synonyms: Array = _dictionary_cache_data.get("synonyms", [])
	if synonyms.size() > 0:
		var synonyms_text: String = ""
		for syn in synonyms:
			if syn is Dictionary:
				synonyms_text += "\n\n" + syn.get("word", "") + "\n" + syn.get("difference", "")
			else:
				synonyms_text += "\n\n" + str(syn)
		SynonymsList.set_text(synonyms_text)
	else:
		SynonymsList.set_text("No synonyms available")

func _on_analysis_task_completed(service_type: String, _remaining: int) -> void:
	if service_type not in ['grammar','style','structure','dictionary']:
		return

	# When a cache task completes, refresh the display for the current paragraph
	# This handles the case where we requested analysis for a specific tab
	if current_paragraph_hash != "" and current_file_path != "":
		# Reload the cache for the current paragraph
		_grammar_cache_data = AnalysisManager.GrammarService.get_grammar_cache(current_paragraph_hash)
		_style_cache_data = AnalysisManager.StyleService.get_style_cache(current_paragraph_hash)
		_structure_cache_data = AnalysisManager.StructureService.get_structure_cache(current_paragraph_hash)

		# Update display for the current active tab
		var active_tab: int = $TabContainer.get_current_tab()
		_update_display_for_active_tab(active_tab)

func _on_word_info_ready(word: String, info: Dictionary) -> void:
	# Store the word info for display
	_dictionary_cache_data = info
	_selected_word = word
	# If dictionary tab is active, update display
	if $TabContainer.get_current_tab() == 3:
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
		3:  # Dictionary tab
			_update_dictionary_display()

	_update_diff_displays()
