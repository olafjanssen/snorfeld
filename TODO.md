# Development plans
- [ ] Simple Git integration
  - [ ] Integrate libgit2 into the project
  - [ ] Check if project in git repo, allow to git init
  - [ ] Show current file changes and diffs
  - [ ] Allow staging files
  - [ ] Allow committing files
  - [ ] Allow push/pull/fetch
  - [ ] Add .snorfeld to .gitignore or create one for a git project
- [ ] World Building panel
  - [ ] Character tab with list of characters and their character sheets
  - [ ] Location tab with list of locations and their descriptions
  - [ ] Plot overview and suggestions
- [ ] LLM Generation
  - [x] Show LLM status and progress in status bar
  - [x] Trigger LLM generation if user clicks paragraph without cache
  - [x] Clear cache of unused cache files (no longer in project)
  - [ ] Schedule chapter and bookwide LLM tasks
- [ ] Architectural design
	- [ ] Rearrange scenes in logical folders


## Features Done
- [x] Saving files
  - [x] Exporting the CodeEdit text back to original format in the file (should be automatic) 
  - [x] Save when changing the editor to another file
  - [x] Save X seconds after the last change of a user to the text (invalidating the timer when the text is changed)
  - [x] Save when the application closes
- [x] Usability updates
  - [x] Automatically open first file of project when opening
  - [x] Automatically open the last opened file of the project when opening
  - [x] Pick a slimmer font for the interface and a more elegant font
  - [x] When the direction changes outside the app the tree must be updated
  - [x] When the opened file is changed outside the app, the text editor must be updated
- [x] UI improvements
  - [x] Decent settings menu styling
  - [x] Better tab panel styling for the editing assistant
  - [x] Status bars and header panels for the different panels
  - [x] Tree view should show root as project folder
  - [x] Tree view should add file and folder icons
