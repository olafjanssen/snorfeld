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

# Paragraph cache progress
signal cache_queue_updated(queued: int, processing: bool)
signal cache_task_started(remaining: int)
signal cache_task_completed(remaining: int)

# Analysis type enum for separate caching
enum AnalysisType { GRAMMAR, STYLE, STRUCTURE }

# Paragraph analysis signals - carry file_path, line_number, and analysis_type
signal request_priority_analysis(file_path: String, line_number: int, analysis_type: int)
signal cache_cleanup_started
signal cache_cleanup_completed(removed_count: int)

# Analysis triggers
signal run_all_analyses
signal run_chapter_analyses

# Embedding indexing triggers
signal index_project_embeddings
signal index_chapter_embeddings

# Character cache progress
signal character_cache_queue_updated(queued: int, processing: bool)
signal character_cache_task_started(remaining: int)
signal character_cache_task_completed(remaining: int)
signal request_priority_character_cache(file_path: String, file_content: String)
signal run_all_character_analyses
signal run_chapter_character_analyses

# Object cache progress
signal object_cache_queue_updated(queued: int, processing: bool)
signal object_cache_task_started(remaining: int)
signal object_cache_task_completed(remaining: int)
signal request_priority_object_cache(file_path: String, file_content: String)
signal run_all_object_analyses
signal run_chapter_object_analyses

# Embedding cache progress
signal embedding_cache_queue_updated(queued: int, processing: bool)
signal embedding_cache_task_started(remaining: int)
signal embedding_cache_task_completed(remaining: int)
signal request_priority_embedding_cache(text_hash: String, file_path: String, text: String, is_chapter: bool)

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
