extends Control

@onready var Correction: PaneledRichTextLabel = $TabContainer/Grammar/MarginContainer/VBoxContainer/Correction
@onready var GrammarExplanation: Label = $TabContainer/Grammar/MarginContainer/VBoxContainer/GrammarExplanation
@onready var Enhancement: PaneledRichTextLabel = $TabContainer/Style/MarginContainer/VBoxContainer/Enhancement
@onready var StyleExplanation: Label = $TabContainer/Style/MarginContainer/VBoxContainer/StyleExplanation
@onready var Suggestion: PaneledRichTextLabel = $TabContainer/Structure/MarginContainer/VBoxContainer/Suggestion
@onready var StructureExplanation: Label = $TabContainer/Structure/MarginContainer/VBoxContainer/StructureExplanation

# Store current context for patch application
var current_paragraph_original_hash: String = ""
var current_file_path: String = ""
var current_paragraph_text: String = ""

func _ready():
	EventBus.paragraph_selected.connect(_on_paragraph_selected)
	EventBus.diff_span_clicked.connect(_on_diff_span_clicked)

func _on_diff_span_clicked(operation: String, word_index: int, text: String):
	# Emit signal to apply the patch to the editor
	EventBus.apply_diff_patch.emit(
		current_paragraph_original_hash,
		current_file_path,
		operation,
		word_index,
		text
	)

func _on_paragraph_selected(original_hash: String, file_path: String, paragraph_text: String):
	current_paragraph_original_hash = original_hash
	current_file_path = file_path
	current_paragraph_text = paragraph_text

	var cache_data := ParagraphService.get_paragraph_cache(original_hash, file_path)
	if cache_data:
		var corrected : String = cache_data.get("analyses",{}).get("grammar",{}).get("corrected", "")

		if current_paragraph_text != corrected:
			var diff_utility: DiffUtility = DiffUtility.new()
			diff_utility.set_control(self)
			Correction.set_text(diff_utility.calculate_diff(current_paragraph_text, corrected))
		else:
			Correction.set_text("No grammar and spelling suggestions.")
			GrammarExplanation.text = ""
		GrammarExplanation.text = cache_data.get("analyses",{}).get("grammar",{}).get("explanation", "")

		var enhanced : String = cache_data.get("analyses",{}).get("style",{}).get("enhanced", "")

		if current_paragraph_text != enhanced:
			var diff_utility: DiffUtility = DiffUtility.new()
			diff_utility.set_control(self)
			Enhancement.set_text(diff_utility.calculate_diff(current_paragraph_text, enhanced))
		else:
			Enhancement.set_text("No stylistic suggestions.")
			StyleExplanation.text = ""
		StyleExplanation.text = cache_data.get("analyses",{}).get("style",{}).get("explanation", "")

		# Structural analysis
		var suggestion : String = cache_data.get("analyses",{}).get("structure",{}).get("suggestion", "")
		if suggestion.length() > 0:
			var diff_utility: DiffUtility = DiffUtility.new()
			diff_utility.set_control(self)
			Suggestion.set_text(diff_utility.calculate_diff(current_paragraph_text, suggestion))
		else:
			Suggestion.set_text("No structural suggestions.")
			StructureExplanation.text = ""
		StructureExplanation.text = cache_data.get("analyses",{}).get("structure",{}).get("explanation", "")

	else:
		# No cache found - queue this paragraph for analysis at the front of the queue
		Correction.set_text("Generating analysis... Please wait.")
		GrammarExplanation.text = ""
		Enhancement.set_text("Generating analysis... Please wait.")
		StyleExplanation.text = ""
		Suggestion.set_text("Generating analysis... Please wait.")
		StructureExplanation.text = ""

		# Queue this single paragraph for immediate processing
		# We need to get the full file content to pass as context
		var file_content := FileUtils.read_file(file_path)
		if file_content != "":
			# Queue with priority - insert at front of queue
			var paragraph_hash := ParagraphService._hash_paragraph(paragraph_text)
			EventBus.request_priority_cache.emit(paragraph_hash, file_path, paragraph_text, file_content)
