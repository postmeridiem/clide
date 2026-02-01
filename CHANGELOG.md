# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-02-01

### Added
- **Skill Installer Service**: Install bundled Claude Code skills (commit, branch, push, pull, stash) to user or project scope
- **TileListView Component**: Reusable card-style list widget with consistent styling
- **TODO.md Integration**: Parse and display project TODO.md files in the TODOs panel
- **File Watcher**: Real-time file system monitoring with reactive updates
- **Git Graph View**: Visual commit graph in sidebar
- **Branch Status Widget**: Enhanced branch display with remote tracking info
- **Theme System**: 22 built-in themes including Summer Night (default)
- **Alt-key Shortcuts**: VSCode-familiar keybindings that don't interfere with input fields

### Changed
- Restructured project with clear separation of controllers, services, and widgets
- Improved panel architecture with state preservation on hide/show
- Enhanced git integration with better status display

### Fixed
- Test fixtures updated for new widget architecture

## [0.1.0] - 2026-01-15

### Added
- Initial project structure and TUI framework
- Basic panel layout (sidebar, workspace, context)
- Claude Code integration as primary workspace
- Pydantic models for data validation
- pytest test infrastructure
