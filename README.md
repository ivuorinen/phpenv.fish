# phpenv.fish

A fast, feature-rich PHP version manager for Fish Shell that acts like goenv or nvm.

## Features

- **Fast version detection** (100-1000x faster than `brew list`)
- **Dynamic version resolution** from [shivammathur/setup-php](https://github.com/shivammathur/setup-php)
- **Multiple version sources**: `.php-version`, `.tool-version`, `composer.json`
- **Auto-installation** of missing PHP versions
- **Extension management** with availability checking
- **Composer.json integration** with full semver support
- **Auto-switching** between versions (configurable)
- **Fisher package manager** support
- **Rich completions** with descriptions

## Installation

### Using Fisher (recommended)

```bash
fisher install ivuorinen/phpenv.fish
```

### Manual Installation

1. Copy files to your fish configuration:
   ```bash
   # Functions
   curl -L https://raw.githubusercontent.com/ivuorinen/phpenv.fish/main/functions/phpenv.fish > ~/.config/fish/functions/phpenv.fish

   # Completions
   curl -L https://raw.githubusercontent.com/ivuorinen/phpenv.fish/main/completions/phpenv.fish > ~/.config/fish/completions/phpenv.fish

   # Configuration
   curl -L https://raw.githubusercontent.com/ivuorinen/phpenv.fish/main/conf.d/phpenv.fish > ~/.config/fish/conf.d/phpenv.fish
   ```

2. Install dependencies:
   ```bash
   brew install jq
   ```

3. Add Homebrew taps:
   ```bash
   brew tap shivammathur/php
   brew tap shivammathur/extensions
   ```

## Quick Start

```bash
# Show available versions
phpenv versions

# Install PHP versions
phpenv install 8.3
phpenv install 8.1

# Set global default
phpenv global 8.3

# Set project-specific version
phpenv local 8.1

# Install extensions
phpenv extensions install xdebug
phpenv extensions install redis

# Configure behavior
phpenv config set auto-switch false  # Disable auto-switching
phpenv config set auto-install true  # Enable auto-installation

# Check installation
phpenv doctor
```

## Commands

### Version Management

- `phpenv install <version>` - Install PHP version
- `phpenv uninstall <version>` - Uninstall PHP version
- `phpenv use <version>` - Use version for current shell
- `phpenv local <version>` - Set version for current project
- `phpenv global <version>` - Set global default version
- `phpenv list` - List installed versions
- `phpenv current` - Show current version
- `phpenv versions` - Show all available versions

### Extension Management

- `phpenv extensions install <ext>` - Install extension for current PHP
- `phpenv extensions uninstall <ext>` - Uninstall extension
- `phpenv extensions list` - List installed extensions
- `phpenv extensions available` - Show available extensions

### Configuration

- `phpenv config get <key>` - Get configuration value
- `phpenv config set <key> <value>` - Set configuration value
- `phpenv config list` - List all configuration

### Utilities

- `phpenv which [binary]` - Show path to PHP binary
- `phpenv doctor` - Check installation health
- `phpenv help` - Show help

## Version Detection

phpenv automatically detects PHP versions from multiple sources (in priority order):

1. **`.php-version`** - Project-specific version file
2. **`.tool-version`** - Tool version file (parses `v8.4` as `8.4`)
3. **`composer.json`** - Both `config.platform.php` and `require.php` with semver support
4. **Global version** - Fish universal variable
5. **System PHP** - Fallback to system installation

### Composer.json Support

Supports all semver constraints:
- `^8.1` → Uses PHP 8.3 (latest 8.x)
- `~8.2.0` → Uses PHP 8.2
- `>=8.0` → Uses PHP 8.3
- `8.1.*` → Uses PHP 8.1

Checks both locations:
```json
{
  "require": {
    "php": "^8.1"
  },
  "config": {
    "platform": {
      "php": "8.2.0"
    }
  }
}
```

## Configuration

### Configuration Keys

- `auto-install` - Auto-install missing versions (default: false)
- `auto-install-extensions` - Install extensions with new PHP versions (default: false)
- `auto-switch` - Auto-switch versions when changing directories (default: true)
- `default-extensions` - Space-separated list of default extensions (default: "opcache")
- `global-version` - Global PHP version

### Configuration Files

phpenv checks these locations (in order):

1. `~/.config/fish/conf.d/phpenv.fish` (preferred)
2. `~/.config/phpenv/config`
3. `~/.phpenv.fish`

### Examples

```bash
# Enable auto-installation
phpenv config set auto-install true

# Disable auto-switching
phpenv config set auto-switch false

# Set default extensions
phpenv config set default-extensions "opcache xdebug redis"

# Enable auto-extension installation
phpenv config set auto-install-extensions true
```

## Supported PHP Versions

Uses [shivammathur/homebrew-php](https://github.com/shivammathur/homebrew-php) with dynamic version detection:

**Version Aliases:**
- `latest` - Latest stable PHP version
- `nightly` - Development version
- `8.x` - Latest PHP 8.x version
- `7.x` - Latest PHP 7.x version
- `5.x` - Latest PHP 5.x version

**Available Versions:** 5.6, 7.0-7.4, 8.0-8.5

## Supported Extensions

Uses [shivammathur/homebrew-extensions](https://github.com/shivammathur/homebrew-extensions):

- xdebug, redis, imagick, mongodb, memcached
- pcov, ast, grpc, protobuf, yaml
- And many more...

## Performance

- **Directory checks**: ~1-5ms (vs ~1000ms for `brew list`)
- **Bulk version detection**: ~10ms for all versions
- **No Ruby overhead** or git operations
- **Efficient caching** and lazy loading

## Auto-switching

phpenv automatically switches PHP versions when you change directories if a version file is detected in the project.

## Fisher Integration

Works seamlessly with Fisher package manager:

```bash
# Install
fisher install ivuorinen/phpenv.fish

# Update
fisher update ivuorinen/phpenv.fish

# Uninstall
fisher remove ivuorinen/phpenv.fish
```

## Troubleshooting

### Check Installation

```bash
phpenv doctor
```

### Common Issues

#### jq not found

```bash
brew install jq
```

#### PHP version not found

```bash
# Add taps manually
brew tap shivammathur/php
brew tap shivammathur/extensions

# Install specific version
phpenv install 8.3
```

#### Slow performance

- phpenv is designed to be fast by avoiding `brew list`
- If performance issues persist, check your filesystem or try `phpenv doctor`

### Debug Information

```bash
# Check current detection
phpenv current

# Check which binary is used
phpenv which php

# List all configuration
phpenv config list
```

## Contributing

Contributions welcome! Please:

1. Follow fish shell best practices
2. Add tests for new functionality
3. Update documentation
4. Maintain performance optimizations

## License

MIT License - see LICENSE file for details.

## Related Projects

- [shivammathur/homebrew-php](https://github.com/shivammathur/homebrew-php)
- [shivammathur/homebrew-extensions](https://github.com/shivammathur/homebrew-extensions)
- [jorgebucaran/fisher](https://github.com/jorgebucaran/fisher)

