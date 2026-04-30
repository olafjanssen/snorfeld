extends Control

@onready var GrammarText: RichTextLabel = $VBoxContainer/GrammarText
@onready var Explanation: RichTextLabel = $VBoxContainer/Explanation

func _ready():
	GlobalSignals.paragraph_selected.connect(_on_paragraph_selected)

func _on_paragraph_selected(paragraph_hash: String, file_path: String):
	var cache_data := ParagraphCache.get_paragraph_cache(paragraph_hash, file_path)
	if cache_data:
		var original : String = cache_data.get("original_text", "")
		var corrected : String = cache_data.get("corrected_text", "")

		if original != corrected:
			var diff_utility: DiffUtility = DiffUtility.new()
			GrammarText.text = diff_utility.calculate_diff(original, corrected)
			#print(GrammarText.text)
		else:
			GrammarText.text = corrected
		Explanation.text = cache_data.get("explanation", "")
	else:
		GrammarText.text = "No cache found for this paragraph"
		Explanation.text = ""
