extends Control

@onready var GrammarText: RichTextLabel = $ScrollContainer/VBoxContainer/GrammarText
@onready var GrammarExplanation: RichTextLabel = $ScrollContainer/VBoxContainer/GrammarExplanation
@onready var StyleText: RichTextLabel = $ScrollContainer/VBoxContainer/StyleText
@onready var StyleExplanation: RichTextLabel = $ScrollContainer/VBoxContainer/StyleExplanation

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

		if original != corrected:
			var diff_utility: DiffUtility = DiffUtility.new()
			StyleText.text = diff_utility.calculate_diff(original, enhanced)
			#print(GrammarText.text)
		else:
			StyleText.text = "No stylistic suggestions."
			StyleExplanation.text = ""
		StyleExplanation.text = cache_data.get("analyses",{}).get("style",{}).get("explanation", "")

	else:
		GrammarText.text = "No cache found for this paragraph"
		GrammarExplanation.text = ""
		StyleText.text = "No cache found for this paragraph"
		StyleExplanation.text = ""
