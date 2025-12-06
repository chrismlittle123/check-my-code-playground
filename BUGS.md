# Bugs Found in check-my-code (cmc)

> **Last Verified:** December 6, 2025 against v1.5.1
> **Status:** Both bugs remain UNFIXED in latest version

---

## Bug #1: Missing Schema File - `cmc validate` Crashes (CRITICAL)

**Severity:** Critical
**Command:** `cmc validate`
**Affected Versions:** 1.4.5, 1.5.1 (still present)
**Status:** ❌ NOT FIXED

### Description
The `cmc validate` command crashes with a file not found error because the `schemas` directory is missing from the npm package distribution.

### Steps to Reproduce
1. Run `cmc validate` in any directory (with or without a cmc.toml)

### Expected Behavior
The command should validate the cmc.toml file against the JSON schema.

### Actual Behavior
```
Error: ENOENT: no such file or directory, open '/opt/homebrew/lib/node_modules/check-my-code/schemas/cmc.schema.json'
```

### Root Cause
The `schemas/` directory was not included in the npm package. The installed package structure shows:
```
/opt/homebrew/lib/node_modules/check-my-code/
├── compatibility.yaml
├── dist/
├── node_modules/
├── package.json
└── README.md
```

No `schemas/` directory is present.

### Impact
- The `cmc validate` command is completely non-functional
- Users cannot validate their cmc.toml files
- CI/CD pipelines using validation will fail

---

## Bug #2: Incorrect Template Name Format in Documentation/Help

**Severity:** Medium
**Commands:** `cmc context --help`, error messages
**Affected Versions:** 1.4.5, 1.5.1 (still present)
**Status:** ❌ NOT FIXED

### Description
The help text and error messages show incorrect template name format that doesn't match the actual available templates.

### Steps to Reproduce
1. Run `cmc context --help`
2. Follow the documented example: `templates = ["typescript/5.5"]`
3. Run `cmc context --target claude --stdout`

### Expected Behavior
The documented template name format should work.

### Actual Behavior
```
Error: Template "typescript/5.5" not found.
Available templates: prototype/python/3.12, prototype/typescript/5.5, internal/python/3.12, internal/typescript/5.5, production/python/3.12, production/typescript/5.5
```

### Documentation Shows (Incorrect)
```
templates = ["typescript/5.5"]
```

### Correct Format
```
templates = ["production/typescript/5.5"]
```

### Affected Locations
1. `cmc context --help` example shows wrong format
2. Error messages from `cmc context` suggest the old format
3. The `cmc info` command shows languages but not available prompt templates

### Impact
- New users will follow documentation and get errors
- Confusion about the correct template naming convention
- Additional time spent debugging configuration

---

## Additional Observations (Minor Issues)

### Observation 1: `cmc generate` accepts invalid template references silently
When using `[rulesets.eslint] template = "nonexistent/template"`, the generate command succeeds without warning that the template doesn't exist. It generates a default config instead of warning the user.

### Observation 2: `cmc info` doesn't show available prompt templates
The `cmc info` command shows supported languages and linters but doesn't list the available prompt templates (production/typescript/5.5, etc.). This would help users discover the correct template names.

### Observation 3: Exit codes could be more consistent
- Exit code 1 = violations found (expected)
- Exit code 2 = user error (invalid args, missing config)
- Exit code 3 = internal error

The missing schema file issue exits with code 3, which is correct, but some error messages could be more helpful.

---

## Test Environment
- **OS:** macOS Darwin 24.6.0
- **cmc version:** Initially tested on 1.4.5, re-verified on 1.5.1
- **Node version:** >= 20 (as required)
- **Install method:** npm global install

## Verification History
| Date | Version | Bug #1 | Bug #2 |
|------|---------|--------|--------|
| 2025-12-06 | 1.4.5 | ❌ Present | ❌ Present |
| 2025-12-06 | 1.5.1 | ❌ Present | ❌ Present |
