# Spike Development Guide

**Last Updated**: 2025-07-13  
**Status**: Living document - update after each spike completion  
**Purpose**: Capture lessons learned and best practices for technology validation spikes

## Overview

This document captures the operational practices and lessons learned from the Phase 0 technology validation spikes. These guidelines ensure consistent methodology, quality, and knowledge transfer across all spike implementations.

## Spike Development Workflow

### 1. Branch Strategy

**Pattern**: `feature/[spike-name]-spike`

- Create dedicated branch for each spike
- Keep spike implementation isolated from main
- All experimental code stays on spike branch
- **Never merge spike branches to main**

### 2. Documentation Strategy

**Dual Commit Pattern**:
1. **Documentation Commit**: Updates to `docs/DEVELOPMENT_PLAN.md` with results
2. **Implementation Commit**: All spike code, configs, and artifacts

**Cherry-pick Process**:
- Documentation commits get cherry-picked to main
- Implementation commits remain on spike branch
- Maintains clean main branch while preserving spike work

### 3. Package Management

**Always Use Latest Packages**:
- Run `flutter pub outdated` before starting spike work
- Update `pubspec.yaml` to latest compatible versions
- Document package updates in commit messages
- **Lesson from Spike 1**: Package updates may affect performance

Example update pattern:
```yaml
# Before
flutter_bloc: ^8.1.3
web_socket_channel: ^2.4.0

# After
flutter_bloc: ^9.1.1
web_socket_channel: ^3.0.3
```

## Spike Implementation Standards

### 4. Code Organization

**Required Files Structure**:
```
spike/[spike-name]-spike/
├── lib/
│   ├── main.dart                    # Entry point
│   ├── automated_test_screen.dart   # Self-running validation
│   ├── [core_implementation].dart   # Main spike logic
│   └── [supporting_files].dart
├── pubspec.yaml                     # Updated dependencies
└── README.md                        # Spike-specific documentation
```

### 5. Testing Requirements

**Automated Validation**:
- Implement self-running tests that require no user interaction
- Include comprehensive performance instrumentation
- Log pass/fail results automatically
- Measure all validation criteria from FRAMEWORK_VALIDATION_PLAN.md

**Example from Spike 1**:
- Automated connection to test target
- Self-executing stress tests
- Real-time performance metrics collection
- Clear pass/fail determination

### 6. Performance Instrumentation

**Required Metrics**:
- Latency measurements (with precise timestamps)
- UI performance (frame time, jank detection)
- Memory usage tracking
- Error rate and recovery statistics

**Implementation Pattern**:
```dart
// Use precise timestamps for latency
final timestamp = DateTime.now().millisecondsSinceEpoch;
final command = '(PING:$commandId:$timestamp)';

// UI performance monitoring
Timer.periodic(Duration(milliseconds: 16), (timer) {
  final frameTime = _stopwatch.elapsedMicroseconds / 1000.0;
  if (frameTime > 16.67) {
    _logger.warning('UI JANK detected: ${frameTime}ms');
  }
});
```

## Results Documentation Standards

### 7. Results Format

**Consistent Documentation Pattern**:
```markdown
**Results**:
- ✅ **[Criterion]**: [Result details]
- ❌ **[Criterion]**: [Failure details and suspected cause]
- ✅ **[Criterion]**: [Success details]

**Key Findings**: 
- [Technical insight 1]
- [Technical insight 2]
- [Performance characteristic or limitation]

**Recommendation**: [Next steps and decision guidance]
```

### 8. Hardware vs Simulator Considerations

**Lessons from Spike 1**:
- High latency (200-230ms) suspected to be simulator limitation
- Real hardware testing required for final validation
- Simulator useful for functional testing, not performance validation
- Document simulator limitations explicitly

## Quality Gates

### 9. Pre-Spike Checklist

- [ ] Branch created from main: `feature/[spike-name]-spike`
- [ ] Flutter packages updated to latest versions
- [ ] FRAMEWORK_VALIDATION_PLAN.md requirements reviewed
- [ ] Success criteria clearly defined
- [ ] Automated test framework planned

### 10. Post-Spike Checklist

- [ ] All validation criteria tested and documented
- [ ] Results documented in DEVELOPMENT_PLAN.md
- [ ] Key findings and recommendations recorded
- [ ] Documentation commit created and cherry-picked to main
- [ ] Implementation commit created on spike branch
- [ ] Next steps identified for subsequent spikes

## Spike-Specific Guidelines

### Communication Spike (Completed)

**Key Learnings**:
- Dart Isolates work correctly for TCP separation
- Simulator introduces artificial latency - hardware needed
- UI jank requires state management optimization
- Package updates don't always affect performance

### Graphics Performance Spike (Next)

**Preparation Recommendations**:
- Focus on CustomPainter with large datasets
- Implement frame rate monitoring from Spike 1
- Test with realistic G-Code file sizes (100k+ line segments)
- Measure memory usage during rendering

### State Management Spike (Future)

**Preparation Recommendations**:
- Build on UI performance insights from Spike 1
- Focus on BLoC optimization patterns
- Test high-frequency event handling (1000 events/10 seconds)
- Validate UI responsiveness under load

## Framework Decision Process

### 11. Decision Criteria

**Success Threshold**: 2 out of 3 spikes must pass core requirements
**Current Status**: 1 spike complete (partial pass - hardware validation needed)

**Re-evaluation Triggers**:
- 2+ spikes fail fundamental requirements
- Hardware testing confirms framework limitations
- Performance gaps cannot be optimized

**Alternative Stack Ready**: Electron/TypeScript/React + Redux

## Team Coordination

### 12. Handoff Preparation

**For Next Agent**:
- Provide complete spike history and results
- Share specific technical findings and limitations
- Identify optimization opportunities discovered
- Recommend specific approaches for next spike

**Documentation Locations**:
- **Progress**: `docs/DEVELOPMENT_PLAN.md`
- **Coordination**: `team/SHARED_WORKSPACE.md`
- **Implementation**: Spike branch commits
- **Best Practices**: This document

## Continuous Improvement

### 13. Post-Spike Review

After each spike, update this document with:
- New lessons learned
- Improved methodologies
- Updated quality gates
- Refined success criteria

This ensures each subsequent spike benefits from prior experience and maintains development velocity.

---

*This guide evolves with each spike completion to capture institutional knowledge and improve development practices.*