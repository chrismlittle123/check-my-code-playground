# Bugs Found in check-my-code (cmc)

> **Last Verified:** December 10, 2025 against v1.7.0

## Active Bugs

No active bugs at this time.

---

## Fixed Bugs

### ~~BUG: Invalid `[prompts]` Templates Pass Validation But Fail at Runtime~~ ✅ FIXED in v1.7.0

**Severity:** Medium

**Description:** Invalid template names in `[prompts].templates` pass schema validation but fail at runtime when using `cmc context`. Templates should be validated against the known list during `cmc validate`.

**Steps to Reproduce:**
```bash
cat > cmc.toml << 'EOF'
[project]
name = "test"

[prompts]
templates = ["invalid/template/name"]
EOF

cmc validate
# Output: ✓ cmc.toml is valid

cmc context --target claude
# Output: Error: Template "invalid/template/name" not found.
```

**Expected Behavior:** `cmc validate` should reject invalid template names with an error listing valid templates.

**Actual Behavior:** Validation passes, error only appears at runtime.

**Valid Templates:** `prototype/python/3.12`, `prototype/typescript/5.5`, `internal/python/3.12`, `internal/typescript/5.5`, `production/python/3.12`, `production/typescript/5.5`

**Fix:** v1.7.0 now validates template names during `cmc validate` using pattern matching:
```
✗ cmc.toml has validation errors:
  - /prompts/templates/0: must match pattern: ^(prototype|internal|production)/(python|typescript)/[0-9]+\.[0-9]+$
```

---

### ~~BUG: Non-Lintable Files Counted as "Checked"~~ ✅ FIXED in v1.6.6

**Severity:** Low

**Description:** Files without recognized extensions (or with non-lintable extensions like `.json`) are reported in the "files checked" count, even though no linter actually processes them.

**Steps to Reproduce:**
```bash
cat > cmc.toml << 'EOF'
[project]
name = "test"
EOF

echo 'const x = 1;' > noextension
echo '{"test": true}' > config.json

cmc check noextension config.json
# Output: ✓ No violations found (2 files checked)
```

**Expected Behavior:** Either:
1. Only count files that were actually linted, or
2. Warn that files have unrecognized extensions

**Actual Behavior:** Files are counted as "checked" even though no linter ran on them, which is misleading.

**Fix:** v1.6.6 now correctly reports "0 files checked" for non-lintable files.

---

### ~~BUG: `[files]` Section `include`/`exclude` Patterns Have No Effect~~ ✅ FIXED in v1.6.5

**Severity:** High

**Description:** The `[files]` section in `cmc.toml` with `include` and `exclude` patterns is completely ignored. Files are linted regardless of these patterns. The config validates successfully but has no effect on which files are checked.

**Steps to Reproduce:**
```bash
mkdir -p src vendor
echo 'const x = 1;' > src/app.ts
echo 'const y = 2;' > vendor/lib.ts
echo 'const z = 3;' > root.ts

cat > cmc.toml << 'EOF'
[project]
name = "test"

[files]
include = ["src/**/*.ts"]
exclude = ["vendor/**/*"]
EOF

cmc check .
# Expected: Only src/app.ts checked
# Actual: All 3 files are checked!
```

**Expected Behavior:** Only files matching `include` patterns (excluding those matching `exclude`) should be checked.

**Actual Behavior:** All TypeScript files in the directory are checked regardless of `[files]` settings.

**Additional Finding:** The `[files]` section accepts any arbitrary keys without validation:
```bash
cat > cmc.toml << 'EOF'
[project]
name = "test"

[files]
totally_invalid_key = ["test"]
EOF

cmc validate
# Output: ✓ cmc.toml is valid
```

**Fix:** v1.6.5 now correctly respects `[files]` include/exclude patterns and rejects unknown keys in the `[files]` section.

---

### ~~BUG: Invalid Linter Names in `[rulesets]` Are Silently Ignored~~ ✅ FIXED in v1.6.5

**Severity:** Medium

**Description:** Using an invalid linter name in the `[rulesets]` section (e.g., `[rulesets.invalidlinter]`) passes validation and is silently ignored at runtime. Users could misconfigure their rulesets without any warning.

**Steps to Reproduce:**
```bash
cat > cmc.toml << 'EOF'
[project]
name = "test"

[rulesets.invalidlinter]
enabled = true
rules = { "some-rule" = "error" }
EOF

cmc validate
# Output: ✓ cmc.toml is valid

cmc check .
# Runs without any warning about invalid linter
```

**Expected Behavior:** Validation should fail for unknown linter names. Valid linters are: `eslint`, `ruff`, `tsc`.

**Actual Behavior:** Invalid linter names are accepted and silently ignored.

**Fix:** v1.6.5 now validates linter names and rejects unknown properties in `[rulesets]` with error: "has unknown property 'invalidlinter'".

---

### ~~BUG: `--quiet --json` Flags Together Produce No Output~~ ✅ FIXED in v1.6.3

**Severity:** Medium

**Description:** When using both `--quiet` and `--json` flags together, `cmc check` produces zero output. The `--json` flag should take precedence and output JSON even in quiet mode, or at minimum the flags should be mutually exclusive with an error message.

**Steps to Reproduce:**
```bash
cmc check --quiet --json .
# Output: (empty)
echo $?
# Output: 1 (or 0 if no violations)
```

**Expected Behavior:** Either output JSON (--json should override --quiet for output), or error saying flags are mutually exclusive.

**Actual Behavior:** No output at all, only exit code.

**Fix:** v1.6.3 now correctly outputs JSON when both flags are used together.

---

### ~~BUG: Invalid `[extends]` Entries Are Silently Ignored~~ ✅ FIXED in v1.6.3

**Severity:** High

**Description:** Invalid entries in the `[extends]` section of `cmc.toml` are silently ignored instead of producing validation errors. This includes non-existent local files, invalid github format strings, and unknown protocols.

**Steps to Reproduce:**
```bash
cat > cmc.toml << 'EOF'
[project]
name = "test"

[extends]
invalid = "github:invalid"
nonexistent = "./does-not-exist.toml"
unknown = "ftp://example.com/config.toml"
EOF

cmc check
# Output: ✓ No violations found (0 files checked)

cmc validate
# Output: ✓ cmc.toml is valid
```

**Expected Behavior:** Validation should fail for:
- `github:invalid` - invalid github format (missing owner/repo/path)
- `./does-not-exist.toml` - file does not exist
- `ftp://...` - unknown protocol

**Actual Behavior:** All invalid extends are silently ignored, `cmc validate` reports config as valid.

**Fix:** v1.6.3 now validates extends entries:
- Unknown keys in `[extends]` are rejected
- Invalid `github:` format strings are rejected with pattern validation
- Only `github:owner/repo/path@version` format is now accepted

---

### ~~BUG: `[tools]` Section Does Not Disable Linters~~ ✅ FIXED in v1.6.3

**Severity:** High

**Description:** Setting `eslint = false`, `ruff = false`, or `tsc = false` in the `[tools]` section has no effect. Linters still run regardless of these settings.

**Steps to Reproduce:**
```bash
cat > cmc.toml << 'EOF'
[project]
name = "test"

[tools]
eslint = false
ruff = false
tsc = false
EOF

echo 'import os' > test.py
echo 'const x: number = "wrong";' > test.ts

cmc check .
# Output still shows eslint and ruff violations!
```

**Expected Behavior:** When `eslint = false`, ESLint should not run. Same for ruff and tsc.

**Actual Behavior:** All linters run regardless of `[tools]` settings.

**Note:** TSC requires `[rulesets.tsc] enabled = true` to run, but `[tools] tsc = true` alone does nothing. This is inconsistent - either `[tools]` should work for all linters, or documentation should clarify the correct configuration.

**Fix:** v1.6.3 now correctly respects `[tools]` settings. Setting `eslint = false` or `ruff = false` properly disables those linters.

---

### ~~BUG: Race Condition When Multiple Extends Reference Same Repository~~ ✅ FIXED in v1.6.2

**Severity:** High

**Description:** When `cmc.toml` has multiple `[extends]` entries that reference the same remote repository (e.g., both eslint and ruff configs from the same standards repo), a race condition occurs. Both extends try to clone/access the same cache directory simultaneously, causing either `ENOTEMPTY` or `File exists` errors.

**Steps to Reproduce:**
```bash
# Create cmc.toml with multiple extends from same repo
cat > cmc.toml << 'EOF'
[project]
name = "test"

[extends]
eslint = "github:chrismlittle123/check-my-code-community/rulesets/production/typescript/5.5/eslint@latest"
ruff = "github:chrismlittle123/check-my-code-community/rulesets/production/python/3.12@latest"
EOF

# Clear cache and run
rm -rf ~/.cmc/cache/
cmc check
```

**Error Output (one of two variants):**
```
Error: ENOTEMPTY, Directory not empty: /Users/.../cache/chrismlittle123-check-my-code-community-latest-xxx
```
or:
```
Error: Failed to load rulesets.json manifest: Failed to clone...: fatal: could not create work tree dir '...': File exists
```

**Expected Behavior:** Multiple extends from the same repository should share a single cache clone and resolve sequentially or use file locking.

**Actual Behavior:** Both extends try to clone the repository in parallel into the same cache directory, causing a race condition.

**Root Cause:** The `loadConfig()` function processes multiple `[extends]` entries in parallel (likely via `Promise.all`), but the cache key is derived from the repository (owner/repo@version), not the full ruleset path. When two extends reference the same repo, both attempt to clone simultaneously.

**Workaround:** Use extends from different repositories, or use pinned versions (may help in some cases).

---

## Test Environment
- **OS:** macOS Darwin 24.6.0
- **cmc version:** 1.7.0
- **Node version:** >= 20 (as required)
- **Install method:** npm global install
