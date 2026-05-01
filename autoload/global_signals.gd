extends Node

# Global signal bus for cross-component communication
@warning_ignore("unused_signal")
signal folder_opened(path: String)
@warning_ignore("unused_signal")
signal file_selected(path: String)
@warning_ignore("unused_signal")
signal request_open_folder
@warning_ignore("unused_signal")
signal file_scanned(path: String, paragraphs: Array, file_content: String)
@warning_ignore("unused_signal")
signal paragraph_selected(original_hash: String, file_path: String, current_text: String)
@warning_ignore("unused_signal")
signal apply_diff_patch(original_hash: String, file_path: String, operation: String, word_index: int, new_text: String)
@warning_ignore("unused_signal")
signal open_settings
@warning_ignore("unused_signal")
signal settings_closed
