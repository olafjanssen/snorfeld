extends Node

# Global state
var current_path: String = ""

# Global signal bus for cross-component communication

# Folder and file navigation
@warning_ignore("unused_signal")
signal folder_opened(path: String)
@warning_ignore("unused_signal")
signal file_selected(path: String)
@warning_ignore("unused_signal")
signal request_open_folder

func _on_folder_opened(path: String):
	current_path = path

func _ready():
	folder_opened.connect(_on_folder_opened)

# File content and scanning
@warning_ignore("unused_signal")
signal file_scanned(path: String, paragraphs: Array, file_content: String)

# Paragraph and diff management
@warning_ignore("unused_signal")
signal paragraph_selected(original_hash: String, file_path: String, current_text: String)
@warning_ignore("unused_signal")
signal apply_diff_patch(original_hash: String, file_path: String, operation: String, word_index: int, new_text: String)
@warning_ignore("unused_signal")
signal diff_span_clicked(operation: String, word_index: int, text: String)

# Settings
@warning_ignore("unused_signal")
signal open_settings
@warning_ignore("unused_signal")
signal settings_closed

# File saving
@warning_ignore("unused_signal")
signal request_save_file(path: String)
@warning_ignore("unused_signal")
signal file_saved(path: String)
@warning_ignore("unused_signal")
signal file_changed(path: String, content: String)
@warning_ignore("unused_signal")
signal request_close_file(path: String)
@warning_ignore("unused_signal")
signal request_save_all_files

# Paragraph cache progress
@warning_ignore("unused_signal")
signal cache_queue_updated(queued: int, processing: bool)
@warning_ignore("unused_signal")
signal cache_task_started(remaining: int)
@warning_ignore("unused_signal")
signal cache_task_completed(remaining: int)
@warning_ignore("unused_signal")
signal request_priority_cache(paragraph_hash: String, file_path: String, paragraph: String, file_content: String)
@warning_ignore("unused_signal")
signal cache_cleanup_started
@warning_ignore("unused_signal")
signal cache_cleanup_completed(removed_count: int)

# Git integration signals
@warning_ignore("unused_signal")
signal git_status_refresh_requested(path: String)
@warning_ignore("unused_signal")
signal git_file_status_changed(file_path: String, status: String)
@warning_ignore("unused_signal")
signal request_open_git_panel
@warning_ignore("unused_signal")
signal request_init_git_repo
@warning_ignore("unused_signal")
signal request_stage_file(file_path: String)
@warning_ignore("unused_signal")
signal request_stage_all
@warning_ignore("unused_signal")
signal request_unstage_file(file_path: String)
@warning_ignore("unused_signal")
signal request_commit(message: String)
@warning_ignore("unused_signal")
signal request_push
@warning_ignore("unused_signal")
signal request_pull
@warning_ignore("unused_signal")
signal request_fetch
