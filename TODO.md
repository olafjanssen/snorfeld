# Development plans
- [ ] Simple Git integration
  - [ ] Integrate libgit2 into the project
  - [ ] Check if project in git repo, allow to git init
  - [ ] Show current file changes and diffs
  - [ ] Allow staging files
  - [ ] Allow committing files
  - [ ] Allow push/pull/fetch
  - [ ] Add .snorfeld to .gitignore or create one for a git project
- [ ] UI improvements
  - [ ] Decent settings menu styling
  - [ ] Better tab panel styling for the editing assistant
  - [ ] Status bars and header panels for the different panels
- [ ] World Building panel
  - [ ] Character tab with list of characters and their character sheets
  - [ ] Location tab with list of locations and their descriptions
  - [ ] Plot overview and suggestions
- [ ] LLM Generation
  - [ ] Show LLM status and progress in status bar
  - [ ] Trigger LLM generation if user clicks paragraph without cache
  - [ ] Trigger LLM generation of all paragraphs upon saving the file
  - [ ] Clear cache of unused cache files (no longer in project)
  - [ ] Schedule chapter and bookwide LLM tasks
- [ ] Usability updates
  - [ ] Automatically open first file of project when opening
  - [ ] Pick a slimmer font for the interface and a more elegant font for the text
- [ ] Architectural design
	- [ ] Rearrange scenes in logical folders


## Features Done
- [x] Saving files
  - [x] Exporting the CodeEdit text back to original format in the file (should be automatic) 
  - [x] Save when changing the editor to another file
  - [x] Save X seconds after the last change of a user to the text (invalidating the timer when the text is changed)
  - [x] Save when the application closes
