# Snakommit

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

### Install from source

```bash
# Clone the repository
git clone https://github.com/yourusername/snakommit.git
cd snakommit

# Install dependencies
bundle install

# Create a symlink to use the tool globally
ln -s "$(pwd)/bin/snakommit" /usr/local/bin/snakommit
```

### Install via Homebrew (Coming soon)

```bash
brew install yourusername/tap/snakommit
```

## Usage

Simply run `snakommit` in your Git repository:

```bash
snakommit
```

This will launch the interactive commit flow that will:

1. Check if you're in a Git repository
2. Detect changes in your working directory
3. Help you stage files if needed
4. Guide you through creating a standardized commit message
5. Commit your changes

### Commands

- `snakommit` - Run the default commit flow
- `snakommit help` - Show help information
- `snakommit version` - Show version information

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

## License

MIT
