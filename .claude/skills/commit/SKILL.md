---
name: commit
description: Create a well-formatted git commit with staged changes
---

# Git Commit

Create a well-formatted commit with staged changes following best practices.

## Steps

1. Run `git status --porcelain` to check for changes
2. If no staged changes, show unstaged files and ask what to stage
3. Run `git diff --cached` to review staged changes
4. Generate a commit message following Conventional Commits format:
   - `feat:` new feature
   - `fix:` bug fix
   - `docs:` documentation
   - `refactor:` code restructuring
   - `test:` adding tests
   - `chore:` maintenance
5. Create commit with the message, adding Co-Authored-By trailer

## Commit Message Format

```
<type>(<scope>): <short description>

<body - what and why, not how>

Co-Authored-By: Claude <noreply@anthropic.com>
```

## Best Practices

- Warn about large commits (>500 lines changed)
- Suggest splitting large changes into smaller commits
- Never skip pre-commit hooks unless explicitly requested

## Changelog

After committing, update `CHANGELOG.md` following [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) format:

1. Add entry under `[Unreleased]` section (create if not exists)
2. Categorize changes:
   - `Added` - new features
   - `Changed` - changes to existing functionality
   - `Deprecated` - features marked for removal
   - `Removed` - removed features
   - `Fixed` - bug fixes
   - `Security` - security-related changes
3. Write entries in imperative mood: "Add feature" not "Added feature"
4. Reference issue numbers where applicable
