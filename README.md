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

You have multiple options to install Snakommit:

#### Option 1: Install to /usr/local/bin (requires sudo)

```bash
# Clone the repository
git clone https://github.com/yourusername/snakommit.git
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

### Install via Homebrew (Coming soon)

```bash
/!\ - (coming soon) - TODO
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

## Troubleshooting

### Command not found after installation

If you encounter a "command not found" error after installation:

1. Make sure the symlink was created successfully
2. If you installed to ~/bin, ensure your PATH includes this directory
3. Try running with the full path to the executable

### Permission issues

If you encounter permission issues during installation:

1. Try the alternative installation methods that don't require sudo
2. Ensure your Ruby environment has the correct permissions
3. Check that the executable bit is set on the bin/snakommit file:
   ```bash
   chmod +x bin/snakommit
   ```

## License

MIT
