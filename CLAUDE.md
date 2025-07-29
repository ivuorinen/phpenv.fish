# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

phpenv.fish is a PHP version manager for Fish Shell, similar to nvm for Node.js.
It provides fast PHP version switching, extension management, and automatic version detection from project files.

## Development Commands

### Testing Changes

Since this is a Fish shell plugin, test changes by:

```bash
# Reload the function after changes
source functions/phpenv.fish

# Test commands
phpenv help
phpenv versions
phpenv current
```

### Installation for Development

```bash
# Link the development version to Fish config
ln -sf $PWD/functions/phpenv.fish ~/.config/fish/functions/phpenv.fish
ln -sf $PWD/completions/phpenv.fish ~/.config/fish/completions/phpenv.fish
ln -sf $PWD/conf.d/phpenv.fish ~/.config/fish/conf.d/phpenv.fish
```

## Code Architecture

### Core Components

1. **Main Dispatcher (`functions/phpenv.fish`)**
   - Entry point function that routes commands to internal functions
   - All subcommands are implemented as `__phpenv_*` functions
   - Version detection logic in `__phpenv_detect_version`

2. **Completions (`completions/phpenv.fish`)**
   - Provides tab completions for all commands
   - Fetches available versions dynamically from shivammathur/setup-php

3. **Configuration (`conf.d/phpenv.fish`)**
   - Sets up Fish universal variables on load
   - Handles PATH initialization

### Key Design Patterns

- **Performance Focus**: Direct directory checks instead of `brew list` (100-1000x faster)
- **Fish Universal Variables**: Used for configuration persistence
- **Homebrew Integration**: Uses shivammathur taps for PHP/extension installation
- **Version File Priority**: `.php-version` > `.tool-version` > `composer.json` > global > system

### Version Detection Flow

1. Check for `.php-version` file (exact version)
2. Check for `.tool-version` file (parse PHP line)
3. Check `composer.json` for PHP constraints (semver resolution)
4. Use global version from Fish universal variable
5. Fall back to system PHP

### Important Implementation Details

- All internal functions are prefixed with `__phpenv_`
- Version resolution supports semver constraints (^8.1, ~8.2.0, etc.)
- Extension management uses separate Homebrew tap
- Auto-switching uses Fish's `pwd` event handler
- Configuration stored in Fish universal variables with `PHPENV_` prefix

## Code Style Requirements

- Maximum line length: 120 characters (enforced by .editorconfig)
- Use LF line endings
- UTF-8 encoding
- Trim trailing whitespace
- Insert final newline

## PATH and Variable Management

### PATH State Tracking

- `PHPENV_ORIGINAL_PATH`: Stores initial PATH before any modifications
- `PHPENV_CURRENT_VERSION`: Tracks currently active PHP version
- `PHPENV_CURRENT_PATH`: Stores path to current PHP binary
- Use `phpenv use system` to restore original PATH

### Variable Scope Strategy

- **Universal variables** (`set -U`): Only `PHPENV_GLOBAL_VERSION` (persists across shells)
- **Session variables** (`set -g`): Configuration settings (per-shell session)
- **Local variables** (`set -l`): Function-scoped, automatically cleaned up

### Auto-Switch Debouncing

- `PHPENV_LAST_SWITCH_TIME`: Prevents excessive PATH changes on rapid directory changes
- 1-second minimum interval between auto-switches
- Early exit if already using correct version

## Common Tasks

### Adding a New Command

1. Add case in main `phpenv` function switch statement
2. Implement `__phpenv_<command>` function
3. Add completions in `completions/phpenv.fish`
4. Update help text in `__phpenv_help`

### Modifying Version Detection

- Edit `__phpenv_detect_version` function
- Maintain priority order of version sources
- Test with various project configurations

### Working with Homebrew Integration

- PHP versions: `shivammathur/php/php@<version>`
- Extensions: `shivammathur/extensions/<extension>@<php-version>`
- Check formula existence before operations

### Performance Optimizations

#### Caching System

- `__phpenv_version_cache`: 5-minute cache for API version data
- `__phpenv_cellar_cache`: Permanent cache for Homebrew Cellar path
- Reduces network calls and filesystem operations

#### Unified Helper Functions

- `__phpenv_parse_version_field`: Single function for all jq parsing (eliminates 9+ duplicated calls)
- `__phpenv_ensure_taps`: Unified Homebrew tap management
- `__phpenv_get_available_extensions`: Shared extension listing logic

### PATH Management Best Practices

- Always check `PHPENV_ORIGINAL_PATH` exists before modification
- Use debouncing for automatic operations
- Validate PHP paths before setting
- Provide restoration mechanism (`phpenv use system`)
- Clean up temporary variables in error cases

### Code Organization Principles

- Cache expensive operations (API calls, filesystem checks)
- Unify repeated patterns into helper functions
- Use session variables instead of universal where possible
- Minimize network requests and subprocess calls
