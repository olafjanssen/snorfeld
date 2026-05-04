extends Node
## Services - Central container for all application services
## Provides unified access to LLM, Analysis, and Git services

# Service references (lazy-loaded via autoloads)
@export var llm_client: Node
@export var analysis_service: Node
@export var git_service: Node

func _ready() -> void:
	# Services are loaded as separate autoloads, this container just groups them
	# The actual service nodes are accessed directly via their autoload names:
	# - LLMClient for LLM API calls
	# - AnalysisService for text analysis
	# - GitService for git operations
	pass
