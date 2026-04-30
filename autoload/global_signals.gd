extends Node

# Global signal bus for cross-component communication
signal folder_opened(path: String)
signal file_selected(path: String)
signal request_open_folder
signal file_scanned(path: String, paragraphs: Array)
signal open_settings
signal settings_closed
