---
name: stash
description: Stash current working directory changes
---

# Git Stash

Stash current working directory changes for later use.

## Steps

1. Run `git status` to show what will be stashed
2. Ask for optional stash message
3. Run `git stash push -m "<message>"` or `git stash push` if no message
4. Confirm stash was created with `git stash list`

## Options

- Include untracked files: `git stash push -u`
- Stash specific files: `git stash push -- <files>`

## Related Commands

- `git stash list` - List all stashes
- `git stash pop` - Apply and remove most recent stash
- `git stash apply` - Apply but keep stash
- `git stash drop` - Remove a stash
