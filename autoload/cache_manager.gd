extends Node
## CacheManager - Central manager for all cache services
## This consolidates multiple autoload singletons into a single autoload
## that instantiates them as children, reducing the autoload count.

# Preloaded service scripts
const GrammarServiceScript = preload("res://autoload/cache/grammar_service.gd")
const StyleServiceScript = preload("res://autoload/cache/style_service.gd")
const StructureServiceScript = preload("res://autoload/cache/structure_service.gd")
const CharacterServiceScript = preload("res://autoload/cache/character_service.gd")
const ObjectServiceScript = preload("res://autoload/cache/object_service.gd")
const EmbeddingServiceScript = preload("res://autoload/cache/embedding_service.gd")

# Public references to child services
var GrammarService: Node
var StyleService: Node
var StructureService: Node
var CharacterService: Node
var ObjectService: Node
var EmbeddingService: Node

func _ready() -> void:
	# Instantiate all cache services as children
	GrammarService = GrammarServiceScript.new()
	add_child(GrammarService)
	GrammarService.name = "GrammarService"

	StyleService = StyleServiceScript.new()
	add_child(StyleService)
	StyleService.name = "StyleService"

	StructureService = StructureServiceScript.new()
	add_child(StructureService)
	StructureService.name = "StructureService"

	CharacterService = CharacterServiceScript.new()
	add_child(CharacterService)
	CharacterService.name = "CharacterService"

	ObjectService = ObjectServiceScript.new()
	add_child(ObjectService)
	ObjectService.name = "ObjectService"

	EmbeddingService = EmbeddingServiceScript.new()
	add_child(EmbeddingService)
	EmbeddingService.name = "EmbeddingService"
