extends Node

# Global signal bus for cross-component communication
signal folder_opened(path: String)
signal file_selected(path: String)
signal request_open_folder
