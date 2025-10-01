# Contributing to phpenv.fish

Thank you for your interest in contributing to phpenv.fish! This document provides guidelines and instructions for contributors.

## Table of Contents

- [Development Setup](#development-setup)
- [Code Architecture](#code-architecture)
- [Making Changes](#making-changes)
- [Testing](#testing)
- [Code Quality](#code-quality)
- [Performance Guidelines](#performance-guidelines)
- [Submitting Changes](#submitting-changes)

## Development Setup

### Prerequisites

- Fish Shell 3.0+
- Homebrew (for PHP version management)
- jq (JSON processor)
- Git

### Installation for Development

1. Fork and clone the repository:

   ```bash
   git clone https://github.com/YOUR-USERNAME/phpenv.fish.git
   cd phpenv.fish
   ```

2. Link the development version to your Fish config:

   ```bash
   # Create backup of existing installation if any
   mv ~/.config/fish/functions/phpenv.fish ~/.config/fish/functions/phpenv.fish.backup 2>/dev/null || true

   # Link development version
   ln -sf $PWD/functions/phpenv.fish ~/.config/fish/functions/phpenv.fish
   ln -sf $PWD/completions/phpenv.fish ~/.config/fish/completions/phpenv.fish
   ln -sf $PWD/conf.d/phpenv.fish ~/.config/fish/conf.d/phpenv.fish
   ```

3. Install dependencies:

   ```bash
   brew install jq
   brew tap shivammathur/php
   brew tap shivammathur/extensions
   ```

4. Set up pre-commit hooks:

   ```bash
   pip install pre-commit
   pre-commit install
   ```

### Testing Changes

Since this is a Fish shell plugin, test changes by:

```bash
# Reload the function after changes
source functions/phpenv.fish

# Test basic commands
phpenv help
phpenv versions
phpenv current
phpenv doctor

# Test specific functionality
phpenv install 8.3  # if not already installed
phpenv use 8.3
phpenv list
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

## Making Changes

### Adding a New Command

1. Add case in main `phpenv` function switch statement
2. Implement `__phpenv_<command>` function
3. Add completions in `completions/phpenv.fish`
4. Update help text in `__phpenv_help`

Example:

```fish
# In main phpenv function
case mynewcommand
    __phpenv_mynewcommand $phpenv_args

# New function implementation
function __phpenv_mynewcommand
    # Implementation here
end
```

### Modifying Version Detection

- Edit `__phpenv_detect_version` function
- Maintain priority order of version sources
- Test with various project configurations

### Working with Homebrew Integration

- PHP versions: `shivammathur/php/php@<version>`
- Extensions: `shivammathur/extensions/<extension>@<php-version>`
- Check formula existence before operations

## Testing

### Manual Testing

Test all major functionality:

```bash
# Version management
phpenv install 8.3
phpenv use 8.3
phpenv local 8.2
phpenv global 8.3

# Extension management
phpenv extensions install xdebug
phpenv extensions list

# Configuration
phpenv config set auto-switch true
phpenv config list

# Diagnostics
phpenv doctor
phpenv current
phpenv which php
```

### Edge Cases

Test edge cases:

- Missing jq dependency
- Network connectivity issues
- Invalid version files
- Corrupt installations
- Missing Homebrew taps

## Code Quality

### Pre-commit Hooks

The repository uses several pre-commit hooks for code quality:

- **Security**: `detect-secrets`, `gitleaks`, `checkov`
- **Shell**: `shellcheck`, `shfmt`
- **Format**: `markdownlint`, `yamllint`
- **General**: File format validation, trailing whitespace removal

Run hooks manually:

```bash
pre-commit run --all-files
```

### Code Style Requirements

- Maximum line length: 120 characters (enforced by `.editorconfig`)
- Use LF line endings
- UTF-8 encoding
- Trim trailing whitespace
- Insert final newline

### Fish Shell Best Practices

- Use local variables (`set -l`) for function scope
- Use session variables (`set -g`) for per-shell configuration
- Use universal variables (`set -U`) only for persistent settings
- Prefix all internal functions with `__phpenv_`
- Use descriptive variable names with `phpenv_` prefix
- Handle errors gracefully with proper return codes

## Performance Guidelines

### Optimization Principles

1. **Cache expensive operations** (API calls, filesystem checks)
2. **Unify repeated patterns** into helper functions
3. **Use session variables** instead of universal where possible
4. **Minimize network requests** and subprocess calls

### Caching System

The codebase uses intelligent caching:

- `__phpenv_version_cache`: 5-minute cache for API version data
- `__phpenv_cellar_cache`: Permanent cache for Homebrew Cellar path

### PATH Management Best Practices

- Always check `PHPENV_ORIGINAL_PATH` exists before modification
- Use debouncing for automatic operations
- Validate PHP paths before setting
- Provide restoration mechanism (`phpenv use system`)
- Clean up temporary variables in error cases

### Helper Functions

Use unified helper functions to avoid code duplication:

- `__phpenv_parse_version_field`: Single function for all jq parsing
- `__phpenv_ensure_taps`: Unified Homebrew tap management
- `__phpenv_get_tap_formulas`: Shared formula listing logic

## Submitting Changes

### Pull Request Process

1. **Create a branch** from `main`:

   ```bash
   git checkout -b feature/my-improvement
   ```

2. **Make focused changes**:
   - Keep changes small and focused
   - Follow the existing code style
   - Add tests if applicable

3. **Run quality checks**:

   ```bash
   pre-commit run --all-files
   shellcheck functions/phpenv.fish
   ```

4. **Test thoroughly**:
   - Test all affected functionality
   - Test edge cases
   - Test on different environments if possible

5. **Commit with clear messages**:

   ```bash
   git commit -m "feat: add new command for X functionality"
   ```

6. **Submit pull request**:
   - Provide clear description of changes
   - Reference any related issues
   - Include testing instructions

### Commit Message Format

Follow conventional commits:

- `feat:` for new features
- `fix:` for bug fixes
- `docs:` for documentation changes
- `perf:` for performance improvements
- `refactor:` for code refactoring
- `test:` for adding tests

### Code Review

All changes require code review. The maintainer will:

- Review for code quality and style
- Test functionality
- Check performance impact
- Verify documentation updates

## Getting Help

- **Issues**: Open a GitHub issue for bugs or feature requests
- **Discussions**: Use GitHub Discussions for questions
- **Documentation**: Check the README and CLAUDE.md files

Thank you for contributing to phpenv.fish! 🐟
