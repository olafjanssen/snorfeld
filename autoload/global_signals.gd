extends Node

# Global signal bus for cross-component communication

# Folder and file navigation
@warning_ignore("unused_signal")
signal folder_opened(path: String)
@warning_ignore("unused_signal")
signal file_selected(path: String)
@warning_ignore("unused_signal")
signal request_open_folder

# File content and scanning
@warning_ignore("unused_signal")
signal file_scanned(path: String, paragraphs: Array, file_content: String)

# Paragraph and diff management
@warning_ignore("unused_signal")
signal paragraph_selected(original_hash: String, file_path: String, current_text: String)
@warning_ignore("unused_signal")
signal apply_diff_patch(original_hash: String, file_path: String, operation: String, word_index: int, new_text: String)

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
