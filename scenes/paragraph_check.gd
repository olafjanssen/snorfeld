extends Control

@onready var GrammarText: RichTextLabel = $TabContainer/Grammar/VBoxContainer/GrammarText
@onready var GrammarExplanation: RichTextLabel = $TabContainer/Grammar/VBoxContainer/GrammarExplanation
@onready var StyleText: RichTextLabel = $TabContainer/Style/VBoxContainer/StyleText
@onready var StyleExplanation: RichTextLabel = $TabContainer/Style/VBoxContainer/StyleExplanation
@onready var StructureText: RichTextLabel = $TabContainer/Structure/VBoxContainer/StructureText
@onready var StructureExplanation: RichTextLabel = $TabContainer/Structure/VBoxContainer/StructureExplanation

func _ready():
	GlobalSignals.paragraph_selected.connect(_on_paragraph_selected)

func _on_paragraph_selected(paragraph_hash: String, file_path: String):
	var cache_data := ParagraphCache.get_paragraph_cache(paragraph_hash, file_path)
	if cache_data:
		var original : String = cache_data.get("original_text", "")
		var corrected : String = cache_data.get("analyses",{}).get("grammar",{}).get("corrected", "")

		if original != corrected:
			var diff_utility: DiffUtility = DiffUtility.new()
			GrammarText.text = diff_utility.calculate_diff(original, corrected)
		else:
			GrammarText.text = "No grammar and spelling suggestions."
			GrammarExplanation.text = ""
		GrammarExplanation.text = cache_data.get("analyses",{}).get("grammar",{}).get("explanation", "")

		var enhanced : String = cache_data.get("analyses",{}).get("style",{}).get("enhanced", "")

		if original != enhanced:
			var diff_utility: DiffUtility = DiffUtility.new()
			StyleText.text = diff_utility.calculate_diff(original, enhanced)
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
