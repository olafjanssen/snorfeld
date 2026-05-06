class_name PromptTemplates
extends RefCounted
## Centralized LLM prompt templates for all analysis services

# ============================================================================
# Paragraph Analysis Prompts
# ============================================================================

# Grammar analysis prompt template
const GRAMMAR_PROMPT := """
You are a helpful writing assistant. Analyze the following text and provide:
1. A corrected version with improved spelling and grammar (keep the original meaning), be aware the text may contain dialogue between \"...\" and MarkDown markup.
2. A brief explanation of the changes made

Context:
{context}

Paragraph to analyze:
{paragraph}

Respond with a JSON object containing 'corrected' and 'explanation' fields:
{{
  \"corrected\": \"[corrected text]\",
  \"explanation\": \"[brief explanation of changes]\"
}}
"""

# Style analysis prompt template
const STYLE_PROMPT := """
You are a helpful writing assistant. Analyze the following text and provide:
1. An enhanced version with improved style, flow, and readability (keep the original meaning)
2. A brief explanation of the stylistic improvements made

Context:
{context}

Paragraph to analyze:
{paragraph}

Respond with a JSON object containing 'enhanced' and 'explanation' fields:
{{
  \"enhanced\": \"[enhanced text]\",
  \"explanation\": \"[brief explanation of stylistic changes]\"
}}
"""

# Structure analysis prompt template
const STRUCTURE_PROMPT := """
You are a helpful writing assistant specializing in story structure. Analyze the following text and provide:
1. A rewrite for this paragraph to improve plot, pacing, or structural flow
2. A brief explanation of how this suggestion enhances the narrative

Context:
{context}

Paragraph to analyze:
{paragraph}

Respond with a JSON object containing 'suggestion' and 'explanation' fields:
{{
  \"suggestion\": \"[structural suggestion]\",
  \"explanation\": \"[brief explanation of the structural improvement]\"
}}
"""

# ============================================================================
# Character Extraction Prompts
# ============================================================================

# Character extraction prompt template
const CHARACTER_EXTRACTION_PROMPT := """
You are a character analysis assistant. Extract all characters from the following chapter text.
For each character mentioned, provide:
- name: The character's name
- description: Brief physical and personality description
- role: Role in the story (protagonist, antagonist, supporting, etc.)
- first_mention: First line or context where they appear in this chapter
- relationships: Connections to other characters mentioned
- motivations: What drives this character in this chapter
- development: How the character changes or what we learn about them

Existing characters (for context - DO NOT re-analyze these unless they appear in the text):
{existing_characters}

Chapter ID: {chapter_id}
Chapter text:
{chapter_text}

Important rules:
- Only include characters that are actually mentioned or appear in this chapter
- For existing characters, only update their data if new information is revealed
- Add new characters that appear for the first time
- Be precise about names - use canonical names from existing characters when matching
- Return an empty characters array if no characters are mentioned

Respond with a JSON object containing 'characters' array of character objects.
"""

# Character description prompt (for single character analysis)
const CHARACTER_DESCRIPTION_PROMPT := """
You are a character analysis expert. Provide a detailed analysis of the following character based on the context provided.

Character name: {character_name}
Context (excerpts where character appears):
{context}

Provide:
1. Physical appearance description
2. Personality traits
3. Role in the story
4. Motivations and goals
5. Relationships with other characters
6. Character arc or development
7. Thematic significance

Respond with a JSON object containing all fields.
"""

# ============================================================================
# Object Extraction Prompts
# ============================================================================

# Object extraction prompt template
const OBJECT_EXTRACTION_PROMPT := """
You are an object analysis assistant (Chekhov's gun principle). Extract all important objects from the following chapter text.
An important object is one that:
- Appears repeatedly or has symbolic meaning
- Could be relevant to plot development (Chekhov's gun)
- Has emotional significance to characters
- Represents themes or motifs

For each important object, provide:
- name: The object's name or description
- description: What it looks like, what it is
- first_mention: First line or context where it appears in this chapter
- character_associations: Which characters interact with or own this object
- thematic_relevance: What themes or symbols this object represents
- plot_potential: How this object might be important later (Chekhov's gun analysis)
- status: Current state/location of the object

Existing objects (for context - DO NOT re-analyze these unless they appear in the text):
{existing_objects}

Chapter ID: {chapter_id}
Chapter text:
{chapter_text}

Important rules:
- Only include objects that are actually mentioned or appear in this chapter
- Focus on objects with potential plot significance, not every random item
- For existing objects, only update their data if new information is revealed
- Add new objects that appear for the first time
- Return an empty objects array if no important objects are mentioned

Respond with a JSON object containing 'objects' array of object objects.
"""

# ============================================================================
# Embedding / Semantic Analysis Prompts
# ============================================================================

# Passage summary prompt (for chapter-level semantic understanding)
const PASSAGE_SUMMARY_PROMPT := """
You are a literary analysis assistant. Provide a comprehensive summary and analysis of the following text passage.

Passage:
{passage}

Provide:
1. summary: Brief summary of what happens (2-3 sentences)
2. themes: Main themes present in this passage
3. tone: The tone or mood of the passage
4. point_of_view: Narrative perspective
5. key_events: Important plot events in order
6. character_focus: Which characters are most prominent
7. setting: Where and when this takes place

Respond with a JSON object containing all fields.
"""

# ============================================================================
# Utility Methods
# ============================================================================

## Format a prompt template with variable substitutions
## Replaces {variable_name} placeholders with values from the vars dictionary
static func format_prompt(template: String, vars: Dictionary) -> String:
	var result := template
	for key in vars:
		var placeholder: String = "{" + key + "}"
		var value: Variant = vars[key]
		# Handle String, int, float, bool, Array, Dictionary
		if value is Array or value is Dictionary:
			value = JsonUtils.stringify_json(value)
		elif value is bool:
			value = "true" if value else "false"
		elif value is int or value is float:
			value = str(value)
		result = result.replace(placeholder, value)
	return result

## Get words from text (helper for context building)
static func get_words(text: String, max_words: int) -> String:
	var words := text.split(" ", false)
	if words.size() <= max_words:
		return text
	var result_words := []
	for i in range(min(words.size(), max_words)):
		result_words.append(words[i])
	return " ".join(result_words)
