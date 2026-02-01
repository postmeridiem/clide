---
name: pull
description: Pull changes from remote with rebase
---

# Git Pull

Pull changes from remote with rebase to keep history clean.

## Steps

1. Check for uncommitted changes - stash if needed
2. Run `git pull --rebase origin <current-branch>`
3. If conflicts occur:
   - Show conflicting files
   - Help resolve conflicts one by one
   - Continue rebase after resolution
4. Pop stash if we stashed earlier

## Conflict Resolution

When conflicts are found:
1. Show the conflicting files with `git status`
2. For each file, show the conflict markers
3. Help user decide how to resolve
4. Stage resolved files with `git add`
5. Continue with `git rebase --continue`

## Best Practices

- Always use rebase for pulls to keep history clean
- Stash local changes before pulling
- Never force push after rebase on shared branches
