# Snakommit

[![Gem Version](https://badge.fury.io/rb/snakommit.svg)](https://badge.fury.io/rb/snakommit)
[![MIT License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Snakommit is a high-performance, interactive commit manager tool similar to Commitizen. It helps teams maintain consistent commit message formats by guiding developers through the process of creating standardized commit messages.

## Features

- Interactive CLI for creating conventional commit messages
- Automatic Git repository detection
- File staging assistance (`git add` functionality)
- Customizable commit types and scopes
- Breaking change detection
- Issue reference linking

## Installation

### Prerequisites

- Ruby >= 2.5
- Git

### Option 1: Install from RubyGems (Recommended)

```bash
# Install the gem
gem install snakommit
```

Or add to your Gemfile:

```ruby
gem 'snakommit'
```

### Option 2: Install from source

You have multiple options to install Snakommit:

#### Option 1: Install to /usr/local/bin (requires sudo)

```bash
# Clone the repository
git clone git@github.com:antonia-pl/snakommit.git
cd snakommit

# Install dependencies
bundle install

# Create a symlink to use the tool globally
sudo ln -s "$(pwd)/bin/snakommit" /usr/local/bin/snakommit
```

#### Option 2: Install to your home directory (no sudo required)

```bash
# Clone the repository
git clone git@github.com:antonia-pl/snakommit.git
cd snakommit

# Install dependencies
bundle install

# Create a bin directory in your home folder (if it doesn't exist)
mkdir -p ~/bin

# Create a symlink in your home bin directory
ln -s "$(pwd)/bin/snakommit" ~/bin/snakommit

# Add this line to your ~/.zshrc or ~/.bash_profile and restart your terminal
# export PATH="$HOME/bin:$PATH"
```

#### Option 3: Run directly from the repository

```bash
# Clone the repository
git clone git@github.com:antonia-pl/snakommit.git
cd snakommit

# Install dependencies
bundle install

# Run snakommit directly
ruby -Ilib bin/snakommit
```

## Usage

Simply run `snakommit` (or its shorter alias `sk`) in your Git repository:

```bash
snakommit  # or 'sk' for short
```

This will launch the interactive commit flow that will:

1. Check if you're in a Git repository
2. Detect changes in your working directory
3. Help you stage files if needed
4. Guide you through creating a standardized commit message
5. Commit your changes

### Commands

- `snakommit` or `sk` - Run the default commit flow
- `snakommit emoji [on|off]` or `sk emoji [on|off]` - Quick toggle for emoji in commit messages
- `snakommit update` or `sk update` - Check for and install the latest version
- `snakommit help` or `sk help` - Show help information
- `snakommit version` or `sk version` - Show version information
- `snakommit templates` or `sk templates` - Manage emoji for commit types
- `snakommit hooks` or `sk hooks` - Manage Git hooks integration

## Configuration

Snakommit uses a YAML configuration file located at `~/.snakommit.yml`. A default configuration is created on first run, which you can customize to fit your project needs.

Example configuration:

```yaml
types:
  - name: feat
    description: A new feature
  - name: fix
    description: A bug fix
  # ... more types
scopes:
  - ui
  - api
  - database
  # ... custom scopes for your project
max_subject_length: 100
max_body_line_length: 72
```

## Troubleshooting

### Command not found after installation

If you encounter a "command not found" error after installation:

1. Make sure the symlink was created successfully
2. If you installed to ~/bin, ensure your PATH includes this directory
3. Try running with the full path to the executable

### Permission issues

If you encounter permission issues during installation:

1. Try the alternative installation methods that don't require sudo.
2. Ensure your Ruby environment has the correct permissions.
3. Check that the executable bit is set on the bin/snakommit file:

```bash
chmod +x bin/snakommit
```

## Development

### CI/CD Workflow

Snakommit uses GitHub Actions for continuous integration and deployment:

- **Automated Testing**: Tests run automatically on multiple Ruby versions (2.7, 3.0, 3.1, 3.2) for all pushes to main and dev branches, as well as pull requests.
- **Code Quality**: Automatic linting with Rubocop ensures consistent code style.
- **Automated Releases**: New versions are published to RubyGems automatically when a release is triggered.

#### Release Process

To create a new release:

1. Go to the GitHub Actions tab
2. Select the "Release" workflow
3. Click "Run workflow"
4. Choose the type of version bump (patch, minor, or major)

This will automatically:
- Run all tests
- Bump the version in the codebase
- Update the CHANGELOG
- Create a Git tag and GitHub release
- Publish to RubyGems.org

## License

MIT

## 📝 Credits & Inspiration

Snakommit was inspired by and builds upon these fantastic projects:

### Similar Tools
- [Commitizen](https://github.com/commitizen/cz-cli) - The original concept of CLI interface for conventional commits
- [Conventional Commits](https://www.conventionalcommits.org/) - The specification for commit messages
- [Gitmoji](https://gitmoji.dev/) - For emoji integration in commit messages

### Other Inspiration
- [Semantic Release](https://github.com/semantic-release/semantic-release) - For commit message structure and formatting
- [AngularJS Commit Guidelines](https://github.com/angular/angular.js/blob/master/DEVELOPERS.md#commits) - The foundation of conventional commits

## Updating

To update Snakommit to the latest version, simply run:

```bash
sk update
```

This will check if a newer version is available on RubyGems.org and install it if found. If you want to force a reinstall of the latest version, you can use:

```bash
sk update --force
```

System-wide installations may require administrator privileges, which the tool will prompt for if needed.

## Performance

Snakommit has been optimized to offer the best possible performance, even on large projects. Here are the key improvements integrated:

### Intelligent Caching

- Expensive Git operations (like getting staged/unstaged files) are cached with a short TTL to optimize performance
- Commit type formatting results with emojis are cached to avoid unnecessary recalculations 
- Configuration is cached with invalidation based on file modification date

### Batch Processing

- Batch processing is used for file operations to reduce system calls
- Automatic parallelization options for large operations when the `parallel` gem is available

### Performance Monitoring

- An integrated monitoring system measures the performance of critical operations
- In DEBUG mode (`SNAKOMMIT_DEBUG=1`), detailed performance information is displayed
- Benchmarking and profiling utilities are available for developers

### Optimized Memory Management

- Efficient use of system resources
- Proactive cache cleaning to reduce memory footprint
- Command pooling to minimize process creation overhead

These optimizations allow Snakommit to remain fast and responsive even on large repositories with many files.
