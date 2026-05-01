extends Control

@onready var GrammarText: ClickableRichTextLabel = $TabContainer/Grammar/VBoxContainer/GrammarText
@onready var GrammarExplanation: RichTextLabel = $TabContainer/Grammar/VBoxContainer/GrammarExplanation
@onready var StyleText: ClickableRichTextLabel = $TabContainer/Style/VBoxContainer/StyleText
@onready var StyleExplanation: RichTextLabel = $TabContainer/Style/VBoxContainer/StyleExplanation
@onready var StructureText: RichTextLabel = $TabContainer/Structure/VBoxContainer/StructureText
@onready var StructureExplanation: RichTextLabel = $TabContainer/Structure/VBoxContainer/StructureExplanation

# Store current context for patch application
var current_paragraph_hash: String = ""
var current_file_path: String = ""
var current_paragraph_text: String = ""

func _ready():
	GlobalSignals.paragraph_selected.connect(_on_paragraph_selected)
	GrammarText.diff_span_clicked.connect(_on_diff_span_clicked)
	StyleText.diff_span_clicked.connect(_on_diff_span_clicked)

func _on_diff_span_clicked(operation: String, word_index: int, text: String):
	# Emit signal to apply the patch to the editor
	GlobalSignals.apply_diff_patch.emit(
		current_paragraph_hash,
		current_file_path,
		current_paragraph_text,
		operation,
		word_index,
		text
	)

func _on_paragraph_selected(paragraph_hash: String, file_path: String, paragraph_text: String):
	current_paragraph_hash = paragraph_hash
	current_file_path = file_path
	current_paragraph_text = paragraph_text

	var cache_data := ParagraphCache.get_paragraph_cache(paragraph_hash, file_path)
	if cache_data:
		var corrected : String = cache_data.get("analyses",{}).get("grammar",{}).get("corrected", "")

		if current_paragraph_text != corrected:
			var diff_utility: DiffUtility = DiffUtility.new()
			GrammarText.text = diff_utility.calculate_diff(current_paragraph_text, corrected)
		else:
			GrammarText.text = "No grammar and spelling suggestions."
			GrammarExplanation.text = ""
		GrammarExplanation.text = cache_data.get("analyses",{}).get("grammar",{}).get("explanation", "")

		var enhanced : String = cache_data.get("analyses",{}).get("style",{}).get("enhanced", "")

		if current_paragraph_text != enhanced:
			var diff_utility: DiffUtility = DiffUtility.new()
			StyleText.text = diff_utility.calculate_diff(current_paragraph_text, enhanced)
		else:
			StyleText.text = "No stylistic suggestions."
			StyleExplanation.text = ""
		StyleExplanation.text = cache_data.get("analyses",{}).get("style",{}).get("explanation", "")

		# Structural analysis
		var suggestion : String = cache_data.get("analyses",{}).get("structure",{}).get("suggestion", "")
		if suggestion.length() > 0:
			StructureText.text = suggestion
		else:
			StructureText.text = "No structural suggestions."
			StructureExplanation.text = ""
		StructureExplanation.text = cache_data.get("analyses",{}).get("structure",{}).get("explanation", "")

	else:
		GrammarText.text = "No cache found for this paragraph"
		GrammarExplanation.text = ""
		StyleText.text = "No cache found for this paragraph"
		StyleExplanation.text = ""
		StructureText.text = "No cache found for this paragraph"
		StructureExplanation.text = ""
