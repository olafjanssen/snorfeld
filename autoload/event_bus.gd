extends Node
## EventBus - Centralized signal bus for the application
@warning_ignore_start("unused_signal")
# gdlint:ignore-file:god-class-signals

# Folder and file navigation
signal folder_opened(path: String)
signal file_selected(path: String)

# Paragraph and diff management
# Carries line number - consumers use BookService to get paragraph data
signal paragraph_selected(file_path: String, line_number: int)
# Word selection signal - carries file_path, line_number, word_index, and the selected word
signal word_selected(file_path: String, line_number: int, word_index: int, word: String)

# For diff span clicks: old_text and new_text are provided
# For change: both are set
# For insert: old_text is empty, new_text is the text to insert
# For delete: old_text is the text to delete, new_text is empty
signal diff_span_clicked(operation: String, word_index: int, old_text: String, new_text: String)

# Settings
signal settings_closed

# Theme
signal theme_changed

# File saving
signal file_saved(path: String)
# In-memory editor content changed (not yet saved to disk)
signal editor_content_changed(path: String, content: String)

# Project lifecycle
signal project_loaded(path: String)
signal project_unloaded
signal content_changed

# Cache service type enum
enum CacheServiceType {
	GRAMMAR,
	STYLE,
	STRUCTURE,
	CHARACTER,
	OBJECT,
	EMBEDDING
}

# Analysis type enum (backward compatibility)
enum AnalysisType { GRAMMAR, STYLE, STRUCTURE }

# Analysis signals - carry service_type for filtering
signal analysis_queue_updated(service_type: String, queued: int)
signal analysis_task_started(service_type: String, remaining: int)
signal analysis_task_completed(service_type: String, remaining: int)
signal analysis_cleanup_started(service_type: String)
signal analysis_cleanup_completed(service_type: String, removed_count: int)

# Git integration signals
signal show_git_diff(file_path: String, diff: String)
signal git_status_updated
signal git_operation_started(operation: String)
signal git_operation_completed(success: bool, message: String)
signal git_repo_changed(is_git_repo: bool)
signal file_status_changed(file_path: String, status: String)

# UI sizes
signal editor_resized
