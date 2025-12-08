# Bugs Found in check-my-code (cmc)

> **Last Verified:** December 8, 2025 against v1.5.9

**No active bugs.** All previously reported issues have been fixed.

---

## Fixed Bugs

### ✅ FIXED in v1.5.9: MCP Server `check_project` Returns "No Lintable Files" for Subdirectories

**Previous Issue:** The MCP server's `check_project` tool failed to find lintable files when given a subdirectory path.

**Status:** Fixed. `src/mcp/handlers.ts` now properly resolves paths relative to `process.cwd()`.

---

### ✅ FIXED in v1.5.9: CLI `check` Command Ignores Multiple File Arguments

**Previous Issue:** When passing multiple file paths to `cmc check`, only the first file was processed.

**Status:** Fixed. `src/cli/commands/check.ts` now accepts `[paths...]` (variadic), and `runCheck()` discovers files from all paths in parallel.

**Verified:**
```bash
$ cmc check test-bugs/test.py test-bugs/newtest/test.py
test-bugs/newtest/test.py:1 [ruff/F401] `os` imported but unused
test-bugs/newtest/test.py:2 [ruff/F401] `sys` imported but unused
test-bugs/test.py:2 [ruff/F401] `os` imported but unused
test-bugs/test.py:3 [ruff/F401] `sys` imported but unused

✗ 4 violations found
```

---

### ✅ FIXED in v1.5.9: CLI Returns Exit Code 0 for Nonexistent Files

**Previous Issue:** When checking a file that doesn't exist, CLI returned exit code 0 (success).

**Status:** Fixed. `src/cli/commands/check.ts` now throws a `ConfigError` when explicit paths are provided but none found, resulting in exit code 2.

**Verified:**
```bash
$ cmc check nonexistent-file.py
Error: Path not found: nonexistent-file.py
$ echo $?
2
```

---

### ✅ FIXED in v1.5.9: TSC Type Checking Ignores File List

**Previous Issue:** When checking specific files, `runTsc()` ignored the file list and checked the entire project.

**Status:** Fixed. `src/linter/runners.ts` now accepts an optional `files` parameter and calls `filterViolationsByFiles()` to filter violations to only include requested files.

---

### ✅ FIXED in v1.5.9: Path Traversal in MCP `check_files`

**Previous Issue:** The `validateFiles()` function didn't validate that resolved paths stay within the project root.

**Status:** Fixed. `src/mcp/utils.ts` now has `isWithinProjectRoot()` function that rejects paths starting with `..`.

**Verified:** Path traversal attempts like `../../../../etc/passwd` are silently rejected (only valid files within project are checked).

---

### ✅ FIXED in v1.5.9: Silent Failure When Linter Output is Malformed JSON

**Previous Issue:** Parser functions silently returned empty arrays when JSON parsing failed.

**Status:** Fixed. `src/linter/parsers.ts` now returns a `ParseResult` with a `parseError` field, and runners properly throw `LinterError` when `parseError` is returned.

---

### ✅ FIXED in v1.5.7: MCP Server `check_files` Tool Path Resolution

**Previous Issue:** The `check_files` tool failed to find files - relative paths returned "No valid files found" and absolute paths had the leading `/` stripped.

**Status:** Fixed. Both relative and absolute paths now work correctly.

---

## Test Environment
- **OS:** macOS Darwin 24.6.0
- **cmc version:** 1.5.9
- **Node version:** >= 20 (as required)
- **Install method:** npm global install
