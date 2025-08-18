# Documentation Consolidation Plan

**Date**: January 18, 2025  
**Purpose**: Streamline and consolidate the docs directory structure

## Current Issues

### 1. **Scattered Information**
- Key information spread across multiple directories
- Redundant content in different locations
- Outdated files that don't reflect current implementation

### 2. **Inconsistent Status**
- Many documents describe planned features as if implemented
- Analysis documents for decisions already made
- Workflow documents for features that don't exist

### 3. **Directory Bloat**
- 4 subdirectories with overlapping purposes
- Many single-purpose files that could be consolidated
- Complex navigation for simple information

## Consolidation Strategy

### Phase 1: Merge Core Documents

**Create consolidated documents:**

1. **GETTING_STARTED.md** - Replace multiple setup documents
2. **CURRENT_STATUS.md** - Replace scattered status information  
3. **PLANNED_FEATURES.md** - Consolidate all future plans
4. **TECHNICAL_REFERENCE.md** - Merge analysis documents

### Phase 2: Eliminate Redundancy

**Remove or merge:**
- Outdated analysis documents (decisions already made)
- Duplicate setup instructions
- Workflow documents for unimplemented features
- Widget specs for non-existent components

### Phase 3: Restructure Directories

**New structure:**
```
docs/
├── README.md                    # Main documentation index
├── GETTING_STARTED.md          # Setup and first steps
├── CURRENT_STATUS.md           # What actually works now
├── PLANNED_FEATURES.md         # Future roadmap and vision
├── TECHNICAL_REFERENCE.md     # Architecture and implementation
├── REFACTORING_PLAN.md        # Current refactoring guidance
└── archive/                    # Moved outdated documents
    ├── analysis/              # Historical analysis
    ├── workflows/             # Planned workflow specs
    └── widgets/               # Planned widget specs
```

## Implementation Plan

### Week 1: Create Consolidated Documents

**GETTING_STARTED.md** - Merge:
- `development/CROSS_PLATFORM_SETUP.md`
- `development/LOCAL_TOOLCHAIN.md`
- `development/AGENT_TOOLS.md`
- `development/QUICK_REFERENCE.md`

**CURRENT_STATUS.md** - Merge:
- `IMPLEMENTATION_STATUS.md`
- Current sections from `DEVELOPMENT_PLAN.md`
- Relevant parts of `ARCHITECTURE.md`

**PLANNED_FEATURES.md** - Merge:
- `PRODUCT_BRIEF.md`
- `REQUIREMENTS.md`
- Future sections from `DEVELOPMENT_PLAN.md`
- All workflow documents

**TECHNICAL_REFERENCE.md** - Merge:
- `ARCHITECTURE.md`
- `DECISIONS.md`
- Relevant analysis documents
- Implementation plans

### Week 2: Archive Outdated Content

Move to `archive/` directory:
- All `analysis/` documents (decisions made)
- All `workflows/` documents (features not implemented)
- All `widgets/` documents (components not built)
- Outdated implementation plans

### Week 3: Update Navigation

- Rewrite `docs/README.md` with new structure
- Update all cross-references
- Validate all links
- Test navigation flow

## Benefits

1. **Easier Navigation** - 4 main documents instead of 30+ files
2. **Current Information** - Clear separation of implemented vs planned
3. **Reduced Maintenance** - Fewer files to keep updated
4. **Better Onboarding** - Single getting started guide
5. **Honest Status** - Clear about what actually works

## Preservation Strategy

- Archive rather than delete outdated content
- Maintain git history for all changes
- Document what was consolidated where
- Keep implementation plans that are actively being followed