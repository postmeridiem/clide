---
name: branch
description: Create, switch, or manage git branches
---

# Git Branch

Create, switch, or manage branches.

## Steps

1. If no argument, list branches with `git branch -a`
2. If branch name provided:
   - Check if it exists
   - If exists: `git checkout <branch>`
   - If not: `git checkout -b <branch>`
3. Show current branch status after switch

## Common Operations

- List all branches: `git branch -a`
- Create and switch: `git checkout -b <name>`
- Switch to existing: `git checkout <name>`
- Delete local branch: `git branch -d <name>`
- Delete remote branch: `git push origin --delete <name>`

## Best Practices

- Use descriptive branch names (feature/*, fix/*, etc.)
- Keep branches short-lived
- Delete merged branches to keep repo clean
