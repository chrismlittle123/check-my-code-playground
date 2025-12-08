# Bugs Found in check-my-code (cmc)

> **Last Verified:** December 8, 2025 against v1.5.9

## Active Bugs

### BUG: CLI `--json` Flag Outputs Plain Text Errors Instead of JSON

**Severity:** Medium

**Description:** When using the `--json` flag with `cmc check`, errors are output as plain text instead of JSON format. This breaks JSON parsing in CI/CD pipelines and tooling that expects consistent JSON output.

**Steps to Reproduce:**
```bash
$ cmc check --json nonexistent-file.py
Error: Path not found: nonexistent-file.py
$ echo $?
2
```

**Expected Behavior:** Error should be returned as JSON:
```json
{
  "error": {
    "code": "CONFIG_ERROR",
    "message": "Path not found: nonexistent-file.py"
  }
}
```

**Actual Behavior:** Plain text error message is output, breaking JSON consumers.

**Location:** `src/cli/commands/check.ts` lines 28-41 - the catch block outputs plain text regardless of `options.json` flag.

---

### BUG: MCP `check_project` Returns "No Lintable Files" for Subdirectories with Own cmc.toml

**Severity:** Medium

**Description:** When calling `check_project` with a subdirectory path that contains its own `cmc.toml`, the MCP server finds the subdirectory's `cmc.toml` as the project root, but then the glob pattern fails to find files because it's searching relative to the wrong location.

**Steps to Reproduce:**
1. Have a project with nested `cmc.toml` files (e.g., `./cmc.toml` and `./test-bugs/cmc.toml`)
2. Call `check_project` with `path: "test-bugs"`
3. Result: `"No lintable files found"` despite files existing

**MCP call:**
```json
{
  "success": true,
  "violations": [],
  "files_checked": 0,
  "has_violations": false,
  "message": "No lintable files found"
}
```

**CLI comparison (works correctly):**
```bash
$ cmc check test-bugs
# Returns 16 violations from files in test-bugs/
```

**Root Cause:** The `loadProjectConfig(path)` function in `handlers.ts:53` searches for `cmc.toml` starting from the given path. When `test-bugs` has its own `cmc.toml`, it becomes the project root. Then `discoverFiles(targetPath, projectRoot)` is called with `targetPath` resolved from `process.cwd()`, but files are returned relative to `projectRoot` (test-bugs), creating a mismatch.

**Location:** `src/mcp/handlers.ts` - `handleCheckProject()` function

---

### BUG: CLI `check` Does Not Support Glob Patterns

**Severity:** Low

**Description:** The CLI `check` command does not expand glob patterns. Users cannot use patterns like `*.py` or `src/**/*.ts` to select files.

**Steps to Reproduce:**
```bash
$ cmc check "test-bugs/*.py"
Error: Path not found: test-bugs/*.py
$ echo $?
2
```

**Expected Behavior:** Glob patterns should be expanded to match files.

**Actual Behavior:** Glob pattern is treated as a literal path, which doesn't exist.

**Note:** This may be intentional design, but is not documented. The shell usually expands globs, but quoted globs are not expanded.

---

### BUG: Broken Symlinks Cause "Path Not Found" Error Instead of Being Skipped

**Severity:** Low

**Description:** When a broken symlink exists in the project and is explicitly passed to `cmc check`, the CLI returns exit code 2 with "Path not found" error. While this is technically correct, broken symlinks discovered during directory traversal should be silently skipped rather than causing errors.

**Steps to Reproduce:**
```bash
$ ln -s /nonexistent/file test-bugs/broken_symlink.ts
$ cmc check test-bugs/broken_symlink.ts
Error: Path not found: test-bugs/broken_symlink.ts
$ echo $?
2
```

**Note:** When scanning directories, broken symlinks are properly skipped. This only affects explicit file arguments.

---

### BUG: Warning Messages Printed to stderr Even in JSON Mode

**Severity:** Low

**Description:** When a linter is not installed (e.g., `ruff` or `eslint`), warning messages are printed to stderr even when `--json` flag is used. This can interfere with JSON parsing when stdout and stderr are combined.

**Location:** `src/linter/runners.ts` lines 32-33, 72-73, 138-139 - `console.error()` calls for missing linters.

**Expected Behavior:** In JSON mode, warnings should either be suppressed or included in the JSON output.

---

### BUG: `cmc audit eslint` Incorrectly Parses Commented-Out Rules

**Severity:** Medium

**Description:** The `cmc audit eslint` command uses regex-based parsing to extract rules from `eslint.config.js`. This parser incorrectly matches rules that appear in comments, causing the audit to believe rules exist when they are actually commented out.

**Steps to Reproduce:**
```bash
# Create cmc.toml expecting a rule
$ cat cmc.toml
[project]
name = "test"
[rulesets.eslint]
rules = { "@typescript-eslint/no-unused-vars" = "warn" }

# Create eslint.config.js with the rule COMMENTED OUT
$ cat eslint.config.js
export default [
  {
    rules: {
      // "@typescript-eslint/no-unused-vars": "warn",
      "no-console": "warn"
    },
  }
];

# Run audit
$ cmc audit eslint
✗ eslint.config.js has mismatches:
  - extra rule: no-console = "warn"
```

**Expected Behavior:** Should report:
- missing rule: `@typescript-eslint/no-unused-vars = "warn"`
- extra rule: `no-console = "warn"`

**Actual Behavior:** Only reports the extra rule. The commented-out rule is incorrectly parsed as if it exists, so no "missing rule" is reported.

**Root Cause:** The `extractESLintRules()` function in `src/cli/commands/audit.ts` uses regex patterns that don't account for JavaScript comments. The regex `/'([^']+)'\s*:\s*(['"][^'"]+['"]|\[[^\]]+\])/g` matches quoted strings regardless of whether they're in comments.

**Location:** `src/cli/commands/audit.ts` - `extractESLintRules()`, `parseRulesManually()` functions (lines ~270-312)

**Impact:** CI/CD pipelines relying on `cmc audit` may incorrectly pass when required rules are commented out, giving false confidence that the ESLint config matches the cmc.toml specification.

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
