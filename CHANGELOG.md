# Changelog

All notable changes to Snorfeld.

## [0.1.5]

### Added
- **Usability**
  - Outline tab showing chapter outline instead of raw files
  - Source and target language selection for translation
  - Dictionary and thesaurus lookup functionality
- **Statistics**
  - Paragraph and chapter embeddings
  - Initial cohesion metrics display

## [0.1.0]

### Added
- **Story Bible Panel**
  - Character tab with character sheets
  - Object/Chekhov's gun overview
- **Architectural Design**
  - Book service for project structure overview
  - Cache storage option: global or per-project
- **LLM Generation**
  - LLM status and progress in status bar
  - On-demand paragraph analysis when clicking uncached paragraphs
  - Chapter and book-wise paragraph scheduling
  - Automatic cache clearing of unused files
- **Simple Git Integration**
  - OS git command integration
  - Git repo detection and initialization
  - File changes and diffs display
  - Staging, committing, push/pull/fetch support
  - Auto-add `.snorfeld` to `.gitignore`
- **Saving**
  - Auto-export CodeEdit text to original file format
  - Auto-save on file switch
  - Auto-save after X seconds of inactivity
  - Save on application close

### Changed
- **Architecture**
  - Split complex methods and classes per GDScript linter guidance
  - Scenes rearranged into logical folder structure
  - Simplified LLM call queueing
  - Overhauled theming system (no more theme overrides for colors/fonts)
  - Cleaned embedding cache no longer stored at every startup
- **UI/UX**
  - Screen pixel density detection for UI scaling
  - Light/dark/OS-auto theme switching
  - Font size scaling for editor
  - Target editor line length configuration
  - Added application icon and about panel
  - Added GitHub Pages webpage
  - Improved settings menu styling
  - Enhanced tab panel styling for editing assistant
  - Added status bars and header panels to panels
  - Tree view shows root as project folder
  - Added file and folder icons to tree view
  - Slimmer interface font, more elegant editor font
  - Tree updates when directory changes externally
  - Text editor updates when opened file changes externally
  - Auto-open first file when opening project
  - Auto-open last opened file when reopening project

### Fixed
- Clicking and undoing diffs now works correctly
- Undo in text editor no longer replaces file with data from other file when switching
- Text editor now scrolls when moving cursor with arrow keys
