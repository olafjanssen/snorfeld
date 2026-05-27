# GDScript Linter - Code Quality Report

Generated: 2026-05-27T19:36:33
Project: snorfeld

---

## Context

When analyzing linter issues, consider both quick fixes AND architectural improvements:

1. **Evaluate the code holistically** - Before suggesting an ignore directive, ask:
   - Could extraction improve testability or reusability?
   - Does this file have multiple responsibilities that should be separated?
   - Would a component/helper class make the code easier to extend?
   - Is the complexity hiding a design problem?

2. **Ignore directives are appropriate when:**
   - Code is clean, readable, and slightly over a limit
   - Extraction would add complexity without clear benefit
   - The "violation" is inherent to the domain (e.g., large enum files)

3. **Refactoring is appropriate when:**
   - Multiple responsibilities are tangled together
   - The same code section is frequently modified
   - Testing requires mocking the entire class
   - New features keep touching the same file

Always explain your reasoning for recommending a refactor vs an ignore directive.

**Required steps:**
- Before adding any ignore directive, read `res://addons/gdscript-linter/docs/IGNORE_RULES.md` for correct syntax
- After completing changes, run the linter via CLI using options in `res://addons/gdscript-linter/docs/CLI.md`

---

## Summary

| Metric | Value |
|--------|-------|
| Files Analyzed | 46 |
| Total Lines | 9882 |
| Total Issues | 14 |
| Critical | 0 |
| Warnings | 1 |
| Info | 13 |
| Debt Score | 1815 |

---

## Issues by File

### `res://scenes/panels/paragraph_check.gd` (7 issues)

- **Line 124** [WARNING]: Function '_update_dictionary_display' has 4 nesting levels (max 3) (`deep-nesting`)
- **Line 153** [INFO]: Line exceeds 120 chars (124) (`long-line`)
- **Line 205** [INFO]: Magic number 4 (consider using a named constant) (`magic-number`)
- **Line 206** [INFO]: Magic number 4 (consider using a named constant) (`magic-number`)
- **Line 236** [INFO]: Magic number 4 (consider using a named constant) (`magic-number`)
- **Line 358** [INFO]: Magic number 3 (consider using a named constant) (`magic-number`)
- **Line 361** [INFO]: Magic number 4 (consider using a named constant) (`magic-number`)

### `res://scenes/editor/code_edit.gd` (5 issues)

- **Line 180** [INFO]: Magic number 58 (consider using a named constant) (`magic-number`)
- **Line 181** [INFO]: Magic number 91 (consider using a named constant) (`magic-number`)
- **Line 182** [INFO]: Magic number 123 (consider using a named constant) (`magic-number`)
- **Line 223** [INFO]: Magic number 33 (consider using a named constant) (`magic-number`)
- **Line 225** [INFO]: Magic number 58 (consider using a named constant) (`magic-number`)

### `res://scenes/main/popup_menu.gd` (2 issues)

- **Line 45** [INFO]: Line exceeds 120 chars (127) (`long-line`)
- **Line 46** [INFO]: Line exceeds 120 chars (127) (`long-line`)

---

## Metadata

- **Generator**: GDScript Linter
- **Analysis Time**: 901ms

> Ask an AI: "Review these issues and suggest fixes for each file."
