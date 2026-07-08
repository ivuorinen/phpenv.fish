# Nitpicker Findings

Generated: 2026-07-04
Last validated: 2026-07-08

Pass 1 scope: version detection/resolution (composer.json, version files, aliases).
Pass 2 scope: whole repository — providers, PATH management, config system,
completions, conf.d, Fisher packaging, CI, docs.
Pass 4 scope: re-review of pass 2/3 fixes plus repo config; pre-commit all-files run (green).
Pass 5 scope: documentation accuracy — README, CONTRIBUTING, CLAUDE.md, help text.
Pass 6 scope: workflow security — zizmor --persona auditor.
Pass 7 scope: changed-files — homebrew builtin-extension skip, tap formula-name
mapping, laravel preset brew-side fix (uncommitted work).

## Summary

- Total: 32 | Open: 0 | Fixed: 32 | Invalid: 0

## Open Findings

(none)

## Fixed

### Pass 1 — 2026-07-04

#### [NIT-1] composer `config.platform.php` used verbatim (PATCH leaks to providers)

Fixed: 2026-07-04
Notes: Critical. `"php": "8.1.12"` produced nonexistent `php@8.1.12` / `php8.1.12-xml`
targets. Added `__phpenv_normalize_version` (MAJOR.MINOR truncation, alias passthrough),
applied at every detection source and both composer branches. Tests cover it.

#### [NIT-2] Invalid jq path `.8.x` — caret constraints resolved to empty when online

Fixed: 2026-07-04
Notes: Critical. `.8.x // "8.4"` is a jq syntax error; `8.x`/`7.x`/`5.x` lookups returned
empty whenever the API was reachable, so `^8.1`-style constraints resolved to nothing.
Bracket notation + fallback-on-empty. Verified live (`^8.1` → `8.5`).

#### [NIT-3] Exact constraints swallowed by fish globs (`8.1.3` → latest)

Fixed: 2026-07-04
Notes: High. Quoted `*` in `case '8.*'` is still a glob, so exact patch constraints matched
it and resolved to latest. Exact-version early return added before the switch.

#### [NIT-4] Default extensions never install: `env` cannot run fish functions

Fixed: 2026-07-04
Notes: High. `env VAR=… <function>` exits 127; the adjacent `set -l` was invisible to the
callee (verified). Replaced with `set -g PHPENV_VERSION_OVERRIDE` + `set -e`.

#### [NIT-5] PATCH versions from any source flowed unnormalized through the system

Fixed: 2026-07-04
Notes: High. `.php-version`, `.tool-version(s)` (asdf writes full versions), global/config
versions used verbatim. Normalized at all detection sources and write sites.

#### [NIT-6] `phpenv use latest` / `phpenv uninstall latest` never resolved aliases

Fixed: 2026-07-04
Notes: Medium. Both now call `__phpenv_resolve_version_alias`.

#### [NIT-7] composer.json only detected in CWD, unlike every other version file

Fixed: 2026-07-04
Notes: Medium. Now searched up the tree via `__phpenv_find_version_file`.

#### [NIT-8] asdf's actual filename `.tool-versions` not recognized

Fixed: 2026-07-04
Notes: Medium. Detection checks both singular and plural; conf.d and docs updated.

#### [NIT-9] `.tool-version` parsing broke on tabs or repeated spaces

Fixed: 2026-07-04
Notes: Low. Replaced grep+split+sed with `string match -r '^php\s+v?(\S+)'`.

### Pass 2 — 2026-07-04

#### [NIT-10] conf.d PATH init never ran in a fresh shell

Fixed: 2026-07-04
Notes: Was open advisory. Internal functions aren't autoloadable by name, so the
`functions -q` guard was always false at startup. `functions phpenv >/dev/null` force-loads
the file (verified: printing a function's definition sources the whole file).

#### [NIT-11] Aliases in version files confused auto-switch

Fixed: 2026-07-04
Notes: Was open advisory. `__phpenv_auto_switch` now resolves aliases before the installed
check; no network cost for plain MAJOR.MINOR input.

#### [NIT-12] Semver parser fetched remote version data even when unused

Fixed: 2026-07-04
Notes: Was open advisory. The three `__phpenv_parse_version_field` lookups moved into the
cases that use them; duplicate `>=` cases merged.

#### [NIT-13] fish_plugins: dead file whose handlers would clobber phpenv commands

Fixed: 2026-07-04
Notes: High (latent). Repo-root `fish_plugins` is not a file Fisher installs (it copies
functions/, completions/, conf.d/, themes/ only), so its 84 lines were dead — and its
`__phpenv_install`/`__phpenv_uninstall --on-event` handlers collide with the real command
implementations in functions/phpenv.fish; if ever sourced, `phpenv uninstall 8.1` would
erase all phpenv variables instead of uninstalling PHP. File deleted. If Fisher lifecycle
cleanup is wanted later, add non-colliding `_phpenv_*` handlers to conf.d.

#### [NIT-14] apt pdo extension passed one bogus package name to apt-get

Fixed: 2026-07-04
Notes: High. `set package_name "a b c"` is a single fish list element; apt-get received
`"php8.1-mysql php8.1-pgsql php8.1-sqlite3"` as one package and always failed. Now a real
list (verified `count` behavior). Redundant mysql/gd cases (identical to default) removed.
Same fix mirrored in ext_uninstall.

#### [NIT-15] Version switch dropped PATH entries added after the first switch

Fixed: 2026-07-04
Notes: High. `__phpenv_set_php_path` rebuilt PATH from `PHPENV_ORIGINAL_PATH`, discarding
anything added since (venv, nvm, direnv). Now filters the current `$PATH`; the provider
pattern/shim filters still prevent PHP-path accumulation; ORIGINAL kept for `use system`.

#### [NIT-16] `phpenv which` mutated apt shim symlinks

Fixed: 2026-07-04
Notes: Medium. The apt `get_php_path` rewrites shims as a side effect, so a query command
silently repointed `php` for every shell. `which` now answers from `/usr/bin/<binary><ver>`
directly under apt.

#### [NIT-22] doctor tap check always reported a warning

Fixed: 2026-07-04
Notes: Low. `set -l tap_status (cmd; echo $status)` captured stdout+status as a list;
`test $tap_status -eq 0` errored on multi-element input (verified), forcing the warning
branch. Replaced with a direct `if` on the command.

#### [NIT-23] `phpenv local`/`phpenv global` accepted arbitrary strings

Fixed: 2026-07-04
Notes: Medium. `phpenv local banana` wrote a version file that poisoned detection for every
shell in that tree. Both now validate via `__phpenv_validate_version` (as `config set
global-version` already did). Test added.

#### [NIT-24] Dead code: four unreferenced functions

Fixed: 2026-07-04
Notes: Low. Deleted `__phpenv_get_env_var`, `__phpenv_get_tap_versions` (verbatim duplicate
of `__phpenv_provider_homebrew_list_available`), legacy `__phpenv_ensure_taps` (only
"caller" was the dead fish_plugins file), and `__phpenv_extension_available`. Zero
references verified by grep.

#### [NIT-25] CI never executed any fish code

Fixed: 2026-07-04
Notes: Medium. Workflows covered linting, CodeQL (actions only), labels, and staleness —
no syntax check or test run. Added `.github/workflows/test.yml` (fish -n on all sources +
`fish tests/version-detection.fish`), pinned to the same checkout SHA the repo uses.

#### [NIT-26] `config get --verbose` mislabeled variable source

Fixed: 2026-07-04
Notes: Low. Reported "fish universal variable" for values that are session (`set -g`)
variables for every key except global-version. Label changed to "fish variable".

### Pass 3 — 2026-07-04

#### [NIT-18] conf.d defaults mask the documented config files

Fixed: 2026-07-04
Notes: Was open Medium. The `~/.config/phpenv/config` / `~/.phpenv.fish` lookup never worked:
conf.d defaults masked it for 4 of 5 keys, and the primary documented source is a fish script
the `grep "^key="` pattern can never match. Resolved by deleting the dead feature: config
lookup is now fish variables only (the `eval` indirection replaced with native `$$var`), and
the README "Configuration Files" section replaced with the actual mechanism.

#### [NIT-19] Uninstalling the active version left stale PATH state

Fixed: 2026-07-04
Notes: Was open advisory. `__phpenv_uninstall` now restores the system PATH when the removed
version is the active one.

#### [NIT-20] Homebrew "latest" trusted remote JSON over local formula state

Fixed: 2026-07-04
Notes: Was open advisory. Added `__phpenv_brew_unversioned_version` (reads the unversioned
`php` formula's MAJOR.MINOR from its Cellar dirname); `is_installed`, `get_php_path`, and
`list_installed` now use it — removing three network-backed lookups. Covered by tests with a
fake Cellar.

#### [NIT-21] auto-install could trigger an interactive PPA prompt from the cd hook

Fixed: 2026-07-04
Notes: Was open advisory. `__phpenv_auto_switch` sets `__phpenv_in_auto_switch` around the
install; `__phpenv_provider_apt_ensure_source` refuses to prompt when it is set and prints a
hint instead.

#### [NIT-17] Completion suggestions duplicated versions

Fixed: 2026-07-04
Notes: Was open Low. Fallback list moved to an `else` branch; the accidental
`command -q curl -a command -q jq` (working only because `-a` is `command --all`) rewritten
as the intended `command -q curl; and command -q jq`.

### Pass 4 — 2026-07-04

#### [NIT-27] Findings ledger IDs did not conform to the audit tooling format

Fixed: 2026-07-04
Notes: Low. check-audit-consistency.py requires `[PREFIX-N]` IDs (`^####\s+\[[A-Z]+-\d+\]`);
the bare numeric `[N]` IDs parsed as zero findings, so the Summary-count validation was
silently vacuous. All IDs renamed to `NIT-N`; checker now passes.

#### [NIT-28] auto-switch guard flag leaked on interrupt, suppressing the PPA prompt forever

Fixed: 2026-07-04
Notes: Medium. The pass-3 fix set a global `__phpenv_in_auto_switch` around the install; a
Ctrl-C mid-install skipped the `set -e`, leaving the flag set so later manual
`phpenv install` runs also refused to prompt for the session. Replaced with a stateless
check: auto-switch runs installs with stdin from /dev/null and the prompt guard is
`not isatty stdin` — no flag to leak, and scripts/CI are covered too.

### Pass 5 — 2026-07-04

#### [NIT-29] Documentation drift: wrong claims and missing features across all docs

Fixed: 2026-07-04
Notes: Medium. Verified every doc claim against the implementation. Wrong: CONTRIBUTING told
contributors to run `shellcheck functions/phpenv.fish` (shellcheck cannot parse fish — the
command errors); CONTRIBUTING/CLAUDE.md claimed conf.d "sets up Fish universal variables"
(it sets session variables; only PHPENV_GLOBAL_VERSION is universal); prerequisites said
Fish 3.0+ but the code uses `"$(...)"` (fish 3.4+). Missing: README had no mention of the
apt/Ondřej provider (half the implementation); `phpenv use system` / no-arg auto-detect
absent from the command list; `.tool-versions`, MAJOR.MINOR normalization, and the test
suite absent from CONTRIBUTING/CLAUDE.md/help text. All corrected; quality-check
instructions now use `fish -n` plus the test suite.

### Pass 6 — 2026-07-04

#### [NIT-30] Workflow hardening: 11 zizmor auditor-persona findings

Fixed: 2026-07-04
Notes: Medium (worst: excessive-permissions). `permissions: read-all` in pr-lint and
sync-labels replaced with `{}` (jobs declare their own); every permission line now carries an
explanatory comment; codeql and stale gained concurrency limits; sync-labels checkout sets
`persist-credentials: false` and drops its redundant token input. One documented exception:
pr-lint's checkout keeps `persist-credentials: true` (the action pushes autofix commits) with
an inline `zizmor: ignore[artipacked]`. Result: zero live findings, one ignored.

### Pass 7 — 2026-07-08

#### [NIT-31] pspell falsely reported as builtin for PHP >= 8.4

Fixed: 2026-07-08
Notes: Medium. pspell left core PHP in 8.4 and shivammathur/extensions has no pspell
formula, but the static builtin list made `phpenv ext install pspell` on PHP >= 8.4
print "built into shivammathur/php, nothing to install" and exit 0 — a false success.
Verified against php@8.1/8.4 and unversioned php (8.5) formula configure flags
(`--with-pspell` present only <= 8.3). Builtin check extracted into
`__phpenv_homebrew_ext_is_builtin` with a version-enumerated pspell case (closed set:
5.6-8.3). Tests cover both sides (8.3 skip, 8.4 brew attempt).

#### [NIT-32] Tap formula-name mapping missed pecl_http

Fixed: 2026-07-08
Notes: Low. Same defect class as the redis->phpredis fix under review: PECL `http` is
packaged as `pecl_http` in shivammathur/extensions, so `phpenv ext install http` (or
composer `ext-http` via from-composer) failed against a nonexistent `http@<ver>`
formula. Scanned all 746 tap formulas: phpredis and pecl_http are the only two
PECL-name mismatches (mongodb1/phalcon3-5/xdebug2/imap-uw are versioned or alternate
variants, not name changes). Added `http` case to `__phpenv_homebrew_ext_formula_name`
with a test.

## Invalid

### Pass 1 — 2026-07-04

(none)

### Pass 2 — 2026-07-04

(none)

### Pass 3 — 2026-07-04

(none)
