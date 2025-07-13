# Git Workflow and Branching Strategy

**Author**: DevOps Engineer  
**Date**: 2025-07-13  
**Purpose**: Define git workflow best practices for feature development, bug fixes, and release management

## Branching Strategy Overview

Our project follows a **GitHub Flow** variant optimized for continuous integration and agent-based development.

### Branch Types

#### Main Branch (`main`)
- **Purpose**: Production-ready code
- **Protection**: Always protected, requires PR approval
- **Deployment**: Automatically deployed to staging/production
- **Direct Commits**: Prohibited - all changes via PR

#### Feature Branches (`feature/`)
- **Purpose**: New features and enhancements
- **Naming**: `feature/short-descriptive-name`
- **Lifespan**: Short-lived (1-5 days typical)
- **Base**: Always created from `main`

#### Bug Fix Branches (`fix/` or `hotfix/`)
- **Purpose**: Bug fixes and corrections
- **Naming**: `fix/issue-description` or `hotfix/critical-issue`
- **Lifespan**: Very short (hours to 1 day)
- **Base**: `main` for regular fixes, `main` for hotfixes

#### Documentation Branches (`docs/`)
- **Purpose**: Documentation-only changes
- **Naming**: `docs/section-or-topic`
- **Lifespan**: Short-lived
- **Base**: Always from `main`

#### Refactor Branches (`refactor/`)
- **Purpose**: Code refactoring without behavior changes
- **Naming**: `refactor/component-or-area`
- **Lifespan**: Medium (2-7 days)
- **Base**: Always from `main`

## Feature Development Workflow

### 1. Planning and Scoping

#### Feature Scope Guidelines
**Good Feature Scope:**
- Single responsibility - one feature or enhancement
- Can be completed in 1-5 days
- Independent of other ongoing work
- Has clear acceptance criteria
- Includes tests and documentation

**Examples of Well-Scoped Features:**
- `feature/machine-connection-dialog`
- `feature/gcode-syntax-highlighting`
- `feature/emergency-stop-button`
- `feature/tool-change-workflow`

**Avoid These Scopes:**
- `feature/complete-ui-redesign` (too large)
- `feature/misc-improvements` (not specific)
- `feature/refactor-and-add-feature` (mixed concerns)

#### Pre-Development Checklist
```markdown
## Feature Planning Checklist
- [ ] Clear feature description and acceptance criteria
- [ ] User stories or requirements documented
- [ ] Estimated completion time (max 5 days)
- [ ] Dependencies identified and resolved
- [ ] Test strategy planned
- [ ] Documentation updates identified
- [ ] No conflicts with other active branches
```

### 2. Branch Creation and Setup

```bash
# Always start from updated main
git checkout main
git pull origin main

# Create feature branch
git checkout -b feature/descriptive-name

# Push branch and set upstream tracking
git push -u origin feature/descriptive-name
```

#### Branch Naming Conventions
```bash
# Features
feature/machine-status-display
feature/adaptive-jog-controls
feature/emergency-procedures

# Bug fixes
fix/connection-timeout-error
fix/ui-layout-mobile
hotfix/critical-safety-stop

# Documentation
docs/api-reference-update
docs/workflow-improvements

# Refactoring
refactor/state-management
refactor/component-structure
```

### 3. Development Best Practices

#### Commit Message Standards
Follow [Conventional Commits](https://www.conventionalcommits.org/) specification:

```bash
# Format
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

**Commit Types:**
- `feat:` - New features
- `fix:` - Bug fixes
- `docs:` - Documentation only
- `style:` - Formatting, missing semicolons, etc.
- `refactor:` - Code refactoring
- `test:` - Adding or modifying tests
- `chore:` - Build process, dependencies, etc.

**Examples:**
```bash
feat(ui): add emergency stop button to main toolbar

- Implements prominent red emergency stop button
- Adds keyboard shortcut (Ctrl+E) for emergency stop
- Includes confirmation dialog for accidental activation
- Updates safety documentation with emergency procedures

Closes #123

fix(connection): resolve timeout errors on slow networks

- Increase connection timeout from 5s to 15s
- Add exponential backoff retry logic
- Improve error messaging for network issues
- Add connection status indicators

refactor(state): migrate from setState to BLoC pattern

- Convert machine state management to BLoC
- Improve testability and separation of concerns
- Maintain existing API compatibility
- Add comprehensive unit tests

docs(workflow): update tool change procedures

- Add safety warnings and best practices
- Include troubleshooting section
- Add visual diagrams for tool installation
- Update cross-references to related workflows
```

#### Development Standards

**Code Quality Requirements:**
- All public APIs must have comprehensive documentation
- Unit tests required for all new functionality
- Integration tests for user-facing features
- No direct commits to main branch
- All commits must pass automated checks

**File Organization:**
- Follow existing project structure
- Update documentation alongside code changes
- Add new files to appropriate directories
- Remove unused files and clean up

### 4. Testing and Validation

#### Pre-PR Testing Checklist
```markdown
## Testing Checklist
- [ ] All new code has unit tests
- [ ] Integration tests pass
- [ ] Manual testing completed
- [ ] Documentation updated
- [ ] No breaking changes (or properly documented)
- [ ] Performance impact assessed
- [ ] Security implications reviewed
- [ ] Cross-platform compatibility verified
```

#### Automated Testing
```bash
# Run all tests before committing
npm test                    # Unit tests
npm run test:integration   # Integration tests
npm run lint               # Code quality
npm run type-check         # Type checking
npm run security-check     # Security scanning
```

### 5. Pull Request Process

#### PR Creation Standards

**PR Title Format:**
```
<type>[scope]: Brief description (max 50 chars)
```

**PR Description Template:**
```markdown
## Summary
Brief description of changes and motivation.

## Type of Change
- [ ] 🚀 New feature
- [ ] 🐛 Bug fix
- [ ] 📚 Documentation update
- [ ] 🔧 Refactoring
- [ ] ⚡ Performance improvement
- [ ] 🔒 Security enhancement

## Changes Made
- Bullet point list of specific changes
- Include file paths for major modifications
- Note any breaking changes

## Testing
- [ ] Unit tests added/updated
- [ ] Integration tests pass
- [ ] Manual testing completed
- [ ] Performance tested
- [ ] Security reviewed

## Documentation
- [ ] Code comments added/updated
- [ ] API documentation updated
- [ ] User documentation updated
- [ ] Changelog updated

## Review Checklist
- [ ] Code follows project standards
- [ ] Tests provide adequate coverage
- [ ] Documentation is comprehensive
- [ ] No security vulnerabilities introduced
- [ ] Performance impact acceptable

## Related Issues
Closes #[issue_number]
Relates to #[issue_number]

## Screenshots (if applicable)
[Add screenshots for UI changes]

## Agent Coordination
- **Primary Agent**: [Claude/Gemini]
- **Review Agent**: [Claude/Gemini/Human]
- **Handoff Notes**: [Any coordination notes]
```

#### PR Size Guidelines
**Ideal PR Size:**
- 50-200 lines of code changes
- 1-5 files modified
- Single logical change
- Can be reviewed in 15-30 minutes

**When to Split Large PRs:**
- More than 500 lines of changes
- Multiple unrelated changes
- Complex logic + UI changes
- Multiple features combined

## Bug Fix Workflow

### 1. Bug Triage and Planning

#### Bug Severity Classification
- **Critical (hotfix/)**: Production broken, security issues, data loss
- **High (fix/)**: Major functionality broken, affects multiple users
- **Medium (fix/)**: Minor functionality issues, workarounds available
- **Low (fix/)**: Cosmetic issues, edge cases

#### Bug Fix Scoping
```markdown
## Bug Fix Planning
- [ ] Bug clearly reproduced and documented
- [ ] Root cause identified
- [ ] Fix approach planned and reviewed
- [ ] Test strategy defined
- [ ] Regression prevention planned
- [ ] Documentation updates identified
```

### 2. Hotfix Process (Critical Issues)

```bash
# For critical production issues
git checkout main
git pull origin main
git checkout -b hotfix/critical-issue-description

# Implement minimal fix
# Test thoroughly
# Create PR with expedited review

# After merge, ensure main is deployed immediately
```

**Hotfix Requirements:**
- Minimal, surgical changes only
- Comprehensive testing required
- Immediate deployment after merge
- Post-mortem analysis required

### 3. Regular Bug Fix Process

```bash
# Standard bug fix workflow
git checkout main
git pull origin main
git checkout -b fix/issue-description

# Implement fix with tests
# Update documentation if needed
# Follow standard PR process
```

## Release Management

### Version Tagging
```bash
# Create release tags on main branch
git tag -a v1.0.0 -m "Release version 1.0.0"
git push origin v1.0.0
```

### Release Branch Strategy (for major releases)
```bash
# Create release branch for stabilization
git checkout -b release/v1.0.0 main

# Only bug fixes allowed on release branch
# Merge release branch to main when ready
# Tag the release on main
```

## Agent-Specific Workflow Guidelines

### Claude Agent Workflow
- **Strengths**: Complex feature planning, comprehensive documentation
- **Preferred Branches**: `feature/`, `docs/`, `refactor/`
- **Focus Areas**: Architecture, workflows, safety-critical features

### Gemini Agent Workflow
- **Strengths**: Rapid prototyping, visual features, research
- **Preferred Branches**: `feature/` (UI-focused), `fix/`
- **Focus Areas**: UI components, performance optimization, quick fixes

### Coordination Protocol
1. **Update shared workspace** before starting branch work
2. **Document branch purpose** and expected completion
3. **Coordinate on overlapping areas** through workspace
4. **Hand off via PR reviews** when appropriate

## Quality Gates and Automation

### Automated Checks (Required)
- **Lint**: Code style and formatting
- **Type Check**: TypeScript/Dart type validation
- **Unit Tests**: Minimum 80% coverage
- **Integration Tests**: Core workflow validation
- **Security Scan**: Dependency and code security
- **Documentation**: Link validation and completeness

### Branch Protection Rules
```yaml
# .github/branch_protection.yml
main:
  required_status_checks:
    - lint
    - type-check
    - unit-tests
    - integration-tests
    - security-scan
  enforce_admins: true
  required_pull_request_reviews:
    required_approving_review_count: 1
    dismiss_stale_reviews: true
  restrictions: null
```

## Emergency Procedures

### Reverting Bad Merges
```bash
# Revert a merge commit
git revert -m 1 <merge-commit-hash>

# Create hotfix to address the reversion
git checkout -b hotfix/revert-bad-merge
```

### Production Rollback
```bash
# Tag current state before rollback
git tag emergency-rollback-point

# Rollback to previous stable release
git checkout <previous-stable-tag>
git checkout -b hotfix/emergency-rollback

# Deploy immediately after creating rollback PR
```

## Metrics and Monitoring

### Branch Health Metrics
- Average branch lifespan
- PR size distribution
- Time to merge
- Revert frequency
- Test coverage trends

### Quality Indicators
- Build success rate
- Test pass rate
- Security scan results
- Documentation coverage
- Code review thoroughness

This git workflow ensures code quality, enables agent collaboration, and maintains project stability while supporting rapid feature development.