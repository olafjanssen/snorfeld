extends Node
## CommandBus - Centralized command bus for the application
## Commands are requests to perform actions (CQRS pattern)
## Use this for all "do something" requests, use EventBus for notifications

@warning_ignore_start("unused_signal")

# Folder and file navigation commands
signal open_folder(path: String)
signal save_file(path: String)
signal save_all_files

# Settings
signal open_settings

# Analysis commands
signal priority_analysis(service_type: String, file_path: String, payload: Dictionary)
signal start_analysis(service_type: String, scope: String)
signal delete_analysis_cache(analysis_type: String)

# Other commands
signal navigate_to_line(file_path: String, line_number: int)
signal apply_diff_patch(file_path: String, line_number: int, operation: String, word_index: int, new_text: String)
signal open_story_bible
