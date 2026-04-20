---
name: push
description: Push current branch to remote
---

# Git Push

Push current branch to remote repository.

## Steps

1. Check if branch has upstream: `git rev-parse --abbrev-ref @{u}`
2. If no upstream, set it: `git push -u origin <branch>`
3. Otherwise: `git push`
4. If push is rejected (non-fast-forward):
   - Suggest pull --rebase first
   - Never force push to main/master without explicit request

## Best Practices

- Never force push to protected branches (main, master, develop)
- Always set upstream on first push with `-u` flag
- If rejected, pull with rebase first rather than force pushing
