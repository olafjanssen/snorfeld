# GDScript Linter - Code Quality Report

Generated: 2026-06-11T11:38:51
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
| Total Lines | 9959 |
| Total Issues | 7 |
| Critical | 1 |
| Warnings | 2 |
| Info | 4 |
| Debt Score | 1900 |

---

## Issues by File

### `res://scenes/panels/paragraph_check.gd` (3 issues)

- **Line 230** [INFO]: Magic number 4 (consider using a named constant) (`magic-number`)
- **Line 231** [INFO]: Magic number 4 (consider using a named constant) (`magic-number`)
- **Line 321** [INFO]: Line exceeds 120 chars (122) (`long-line`)

### `res://scenes/editor/code_edit.gd` (2 issues)

- **Line 244** [WARNING]: Function '_on_gui_input' has 6 nesting levels (max 3) (`deep-nesting`)
- **Line 258** [INFO]: Magic number 5 (consider using a named constant) (`magic-number`)

### `res://analysis/dictionary_service.gd` (2 issues)

- **Line 131** [CRITICAL]: Function '_build_dictionary_prompt' has complexity 18 (max 15) (`high-complexity`)
- **Line 176** [WARNING]: Function '_parse_dictionary_response' has complexity 11 (warning at 10) (`high-complexity`)

---

## Metadata

- **Generator**: GDScript Linter
- **Analysis Time**: 605ms

> Ask an AI: "Review these issues and suggest fixes for each file."
