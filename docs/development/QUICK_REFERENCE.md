# Git Workflow Quick Reference

## Daily Development Commands

### Starting New Work
```bash
# Always start from main
git checkout main && git pull origin main

# Create feature branch
git checkout -b feature/your-feature-name
git push -u origin feature/your-feature-name
```

### Making Changes
```bash
# Stage changes
git add .

# Commit with conventional format
git commit -m "feat(scope): description"

# Push changes
git push
```

### Creating Pull Request
```bash
# Push final changes
git push

# Create PR (manual via GitHub UI or gh CLI)
gh pr create --title "feat: Your feature" --body "Description"
```

## Branch Naming Cheat Sheet

| Type | Format | Example |
|------|---------|---------|
| Feature | `feature/description` | `feature/machine-connection` |
| Bug Fix | `fix/description` | `fix/timeout-error` |
| Hotfix | `hotfix/description` | `hotfix/critical-stop` |
| Docs | `docs/section` | `docs/api-reference` |
| Refactor | `refactor/area` | `refactor/state-management` |

## Commit Message Format

```
<type>[scope]: <description>

[optional body]

[optional footer]
```

### Common Types
- `feat:` - New feature
- `fix:` - Bug fix  
- `docs:` - Documentation
- `refactor:` - Code refactoring
- `test:` - Adding tests
- `chore:` - Build/deps

## Pre-PR Checklist

- [ ] Tests pass locally
- [ ] Code follows style guidelines
- [ ] Documentation updated
- [ ] No sensitive data committed
- [ ] Breaking changes documented
- [ ] PR description complete

## Emergency Commands

### Undo Last Commit (not pushed)
```bash
git reset --soft HEAD~1
```

### Undo Changes to File
```bash
git checkout -- filename
```

### Switch Branches with Uncommitted Changes
```bash
git stash
git checkout other-branch
git stash pop  # when returning
```

### Fix Wrong Branch
```bash
git stash
git checkout correct-branch
git stash pop
```

## Agent Coordination

### Before Starting Work
1. Update `/team/SHARED_WORKSPACE.md`
2. Check for conflicting work
3. Document your planned changes

### When Handing Off
1. Push all changes
2. Update shared workspace
3. Create handoff document if needed

### Code Review Process
1. Assign appropriate reviewer
2. Address feedback promptly  
3. Update documentation as needed
4. Merge when approved