extends Node
## EventBus - Centralized signal bus for the application

@warning_ignore_start("unused_signal")

# Folder and file navigation
signal folder_opened(path: String)
signal file_selected(path: String)
signal request_open_folder
signal navigate_to_line(file_path: String, line_number: int)

# Paragraph and diff management
# Carries line number - consumers use BookService to get paragraph data
signal paragraph_selected(file_path: String, line_number: int)
# Uses line_number instead of hash - consumers use BookService to verify and get paragraph
signal apply_diff_patch(file_path: String, line_number: int, operation: String, word_index: int, new_text: String)
signal diff_span_clicked(operation: String, word_index: int, text: String)

# Settings
signal open_settings
signal settings_closed

# Theme
signal theme_changed

# Story Bible
signal open_story_bible

# File saving
signal request_save_file(path: String)
signal file_saved(path: String)
signal file_changed(path: String, content: String)
signal request_close_file(path: String)
signal request_save_all_files

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

# Priority analysis request (unified)
signal request_priority_analysis(service_type: String, file_path: String, payload: Dictionary)

# Unified cache signals - carry service_type for filtering
signal cache_queue_updated(service_type: String, queued: int, processing: bool)
signal cache_task_started(service_type: String, remaining: int)
signal cache_task_completed(service_type: String, remaining: int, result: Dictionary)
signal unified_cache_cleanup_started(service_type: String)
signal unified_cache_cleanup_completed(service_type: String, removed_count: int)

# Analysis triggers
signal run_all_analyses
signal run_chapter_analyses

# Unified analysis trigger (replaces service-specific signals)
# service_type: CacheServiceType enum value as string (GRAMMAR, STYLE, STRUCTURE, CHARACTER, OBJECT, EMBEDDING)
# scope: "project" (all files), "chapter" (current file), "paragraph" (single paragraph)
signal start_analysis(service_type: String, scope: String)

# Embedding indexing triggers
signal index_project_embeddings
signal index_chapter_embeddings

# Git integration signals
signal git_status_refresh_requested(path: String)
signal git_file_status_changed(file_path: String, status: String)
signal show_git_diff(file_path: String, diff: String)
signal git_status_updated(status: Dictionary)
signal git_diff_available(file_path: String, diff: String)
signal git_operation_started(operation: String)
signal git_operation_completed(operation: String, success: bool, message: String)
signal git_repo_changed(is_git_repo: bool)
signal file_status_changed(file_path: String, status: String)
signal request_open_git_panel
signal request_init_git_repo
signal request_stage_file(file_path: String)
signal request_stage_all
signal request_unstage_file(file_path: String)
signal request_commit(message: String)
signal request_push
signal request_pull
signal request_fetch
