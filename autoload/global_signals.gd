extends Node

# Global signal bus for cross-component communication
signal folder_opened(path: String)
signal file_selected(path: String)
signal request_open_folder
signal file_scanned(path: String, paragraphs: Array, file_content: String)
signal paragraph_selected(paragraph_hash: String, file_path: String)
signal open_settings
signal settings_closed
