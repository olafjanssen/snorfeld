# GDScript Linter - Code Quality Report

Generated: 2026-05-08T00:41:12
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
| Total Lines | 9321 |
| Total Issues | 17 |
| Critical | 0 |
| Warnings | 1 |
| Info | 16 |
| Debt Score | 1465 |

---

## Issues by File

### `res://analysis/analysis_service.gd` (9 issues)

- **Line 141** [INFO]: Parameter 'cache_path' is declared but never used (`unused-parameter`)
- **Line 141** [INFO]: Parameter 'project_path' is declared but never used (`unused-parameter`)
- **Line 251** [INFO]: Variable 'decoded_data' has no type annotation (`missing-type-hint`)
- **Line 258** [INFO]: Variable 'result' has no type annotation (`missing-type-hint`)
- **Line 266** [INFO]: Variable 'result' has no type annotation (`missing-type-hint`)
- **Line 278** [INFO]: Variable 'encoded_data' has no type annotation (`missing-type-hint`)
- **Line 294** [INFO]: Variable 'encoded_data' has no type annotation (`missing-type-hint`)
- **Line 352** [INFO]: Variable 'merged' has no type annotation (`missing-type-hint`)
- **Line 429** [INFO]: Parameter 'scope' is declared but never used (`unused-parameter`)

### `res://analysis/merge_utils.gd` (4 issues)

- **Line 21** [INFO]: Variable 'merged' has no type annotation (`missing-type-hint`)
- **Line 27** [INFO]: Variable 'merged' has no type annotation (`missing-type-hint`)
- **Line 96** [INFO]: Variable 'result' has no type annotation (`missing-type-hint`)
- **Line 103** [INFO]: Variable 'strategy' has no type annotation (`missing-type-hint`)

### `res://analysis/embedding_service.gd` (3 issues)

- **Line 112** [INFO]: Variable 'decoded_data' has no type annotation (`missing-type-hint`)
- **Line 135** [INFO]: Variable 'decoded_data' has no type annotation (`missing-type-hint`)
- **Line 154** [INFO]: Variable 'encoded_data' has no type annotation (`missing-type-hint`)

### `res://analysis/object_service.gd` (1 issues)

- **Line 127** [WARNING]: Variable 'success' is declared but never used (`unused-variable`)

---

## Metadata

- **Generator**: GDScript Linter
- **Analysis Time**: 484ms

> Ask an AI: "Review these issues and suggest fixes for each file."
