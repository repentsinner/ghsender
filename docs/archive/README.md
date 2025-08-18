# Documentation Archive

**Date Archived**: January 18, 2025  
**Reason**: Documentation consolidation - moved from scattered structure to 4 main documents

## What's Here

This directory contains historical documentation that was consolidated into the main documentation files. Content is preserved for reference but may be outdated.

### **analysis/** - Technical Analysis Documents
*Status: Decisions made, analysis complete*
- Framework comparisons and technology choices
- Architecture analysis and component design
- Performance analysis and optimization strategies
- **Consolidated into**: `TECHNICAL_REFERENCE.md`

### **workflows/** - User Workflow Specifications  
*Status: Features not implemented*
- Detailed workflow specifications for planned features
- Manual operation procedures (tool changes, touchoff)
- Safety procedures and validation steps
- **Consolidated into**: `PLANNED_FEATURES.md`

### **widgets/** - UI Component Specifications
*Status: Components not built*
- Digital Readout (DRO) widget specifications
- Jog controls widget requirements
- UI component design documents
- **Consolidated into**: `PLANNED_FEATURES.md`

### **development/** - Development Setup Guides
*Status: Consolidated for easier maintenance*
- Cross-platform setup instructions
- Local toolchain configuration
- Agent tools integration
- Git workflow and collaboration
- **Consolidated into**: `GETTING_STARTED.md`

## Why Archived

1. **Scattered Information** - 30+ files made navigation difficult
2. **Outdated Content** - Many documents described planned features as implemented
3. **Redundant Content** - Similar information in multiple locations
4. **Maintenance Burden** - Too many files to keep updated

## New Structure

The consolidated documentation structure:
- `GETTING_STARTED.md` - Setup and development workflow
- `CURRENT_STATUS.md` - What actually works now
- `PLANNED_FEATURES.md` - Product vision and roadmap
- `TECHNICAL_REFERENCE.md` - Architecture and implementation

## Using Archived Content

**For Historical Reference:**
- Understanding past decisions and analysis
- Detailed specifications for planned features
- Original workflow designs and requirements

**For Implementation:**
- Workflow documents contain detailed specifications for future implementation
- Widget specifications provide UI component requirements
- Analysis documents show reasoning behind architectural decisions

**Note**: Archived content may not reflect current implementation status. Always check the main documentation for current information.

## Git History

All content moves preserve git history. Use `git log --follow` to track file history across the move operations.