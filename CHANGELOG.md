# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
### Added
- CI/CD pipeline for automated testing and releases
- Automated RubyGems publishing

## [0.1.1] - 2023-04-01
### Added
- Support for emoji in commit messages with toggle capability
- Performance optimization features including caching and batch processing
- Enhanced Git hooks integration with automatic install/uninstall
- Custom emoji configuration with YAML file support
- Added comprehensive credits and acknowledgements
- Added `sk` command as a shorter alias for `snakommit`
- File selection persistence between sessions
- Quick emoji toggle with `sk emoji on|off` command
- Self-update functionality with `sk update` command

## [0.1.0] - 2025-03-09
### Added
- Initial release
- Interactive CLI for creating conventional commit messages
- Automatic Git repository detection
- File staging assistance (`git add` functionality)
- Customizable commit types and scopes
- Breaking change detection
- Issue reference linking

## 🚀 Roadmap

Future releases will focus on:

### Performance Optimizations
- [ ] Parallel processing for large repositories
- [ ] Smart caching of Git operations
- [ ] Optimized file status detection
- [ ] Performance profiling and monitoring

### Additional Commit Message Templates
- [ ] Support for more conventional formats
- [ ] Custom template creation UI
- [ ] Import/export of templates
- [ ] Enhanced validation rules

### Enhanced Git Hooks Integration
- [ ] Pre-push hook integration
- [ ] Custom hook scripting
- [ ] CI/CD system integration
- [ ] Repository-specific configurations 