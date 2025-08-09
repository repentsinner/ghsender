# Static Analysis and Git Hooks

This document describes the static analysis setup and git commit hooks for the Flutter projects in this repository.

## Current Status

The Flutter project at `spike/graphics_performance_spike` currently has **146 static analysis issues** that need to be addressed:

- **15 warnings** (must fix - these are blocking issues)
- **131 info/lint issues** (should fix for code quality)

## Static Analysis Tools

We use the following static analysis tools:

- `dart analyze` - Dart's built-in static analyzer
- `flutter analyze` - Flutter's wrapper around dart analyze with additional Flutter-specific checks

Both tools use the configuration in `analysis_options.yaml` which includes:
- `package:flutter_lints/flutter.yaml` - Standard Flutter lint rules
- Custom rule overrides as needed

## Git Commit Hooks

Two git pre-commit hooks have been set up to ensure code quality:

### 1. Strict Hook (Active) - `/Users/ritchie/development/ghsender/.git/hooks/pre-commit`

- **Blocks commits** when any warnings or errors are found
- Uses `dart analyze --fatal-warnings`
- Ensures highest code quality standards
- Currently active and will prevent commits until issues are resolved

### 2. Lenient Hook (Alternative) - `/Users/ritchie/development/ghsender/.git/hooks/pre-commit-errors-only`

- **Only blocks commits** for actual errors (not warnings)
- Allows warnings to pass through
- Good for gradual cleanup of legacy code
- Can be activated by renaming to `pre-commit` if preferred

## Using the Hooks

### Normal Development
Just commit as usual:
```bash
git add .
git commit -m "Your commit message"
```

If static analysis issues are found, the commit will be blocked with helpful output.

### Bypassing the Hook (Emergency Only)
If you need to commit urgent changes despite static analysis issues:
```bash
git commit --no-verify -m "Emergency commit - analysis issues to be fixed"
```

**Note:** Use `--no-verify` sparingly and always fix issues in follow-up commits.

### Switching Hook Modes
To switch from strict to lenient mode:
```bash
cd /Users/ritchie/development/ghsender/.git/hooks
mv pre-commit pre-commit-strict
mv pre-commit-errors-only pre-commit
```

To switch back:
```bash
cd /Users/ritchie/development/ghsender/.git/hooks
mv pre-commit pre-commit-errors-only
mv pre-commit-strict pre-commit
```

## Fixing Static Analysis Issues

### High Priority Issues (Must Fix - 15 warnings)

1. **Unused Imports** (11 issues)
   ```dart
   // Remove these lines:
   import 'package:flutter/material.dart';  // lib/gcode/gcode_parser.dart:4
   import 'dart:async';                     // lib/main.dart:1
   import 'dart:math';                      // lib/renderers/filament_renderer.dart:1
   // ... and 8 more
   ```

2. **Unused Fields** (3 issues)
   ```dart
   // Either use these fields or remove them:
   final double _rapidMoveHeight;  // lib/gcode/gcode_scene.dart:39
   final int _targetDrawCalls;     // lib/main.dart:59
   final int _targetPolygons;      // lib/main.dart:60
   ```

3. **Null Comparison Logic Errors** (3 issues)
   ```dart
   // Fix these logical errors in lib/renderers/gpu_batch_renderer.dart:
   // Line 425: condition is always false
   // Line 445: condition is always true
   // Line 489: condition is always true
   ```

### Medium Priority Issues (Should Fix - 131 issues)

1. **Replace print() with logging** (88 issues)
   Consider adding a logging framework like `logger` package:
   ```dart
   // Instead of:
   print('Debug message');
   
   // Use:
   logger.d('Debug message');
   ```

2. **Add @override annotations** (18 issues)
   ```dart
   @override
   bool get initialized => _initialized;
   ```

3. **Fix deprecated API usage** (5 issues)
   ```dart
   // Replace deprecated Flutter GPU API calls:
   // Old: color.red
   // New: (color.r * 255.0).round().clamp(0, 255)
   ```

4. **Remove unnecessary braces** (10 issues)
   ```dart
   // Change: "Position: ${position.x}, ${position.y}"
   // To:     "Position: $position.x, $position.y"
   ```

5. **Use rethrow instead of throw** (2 issues)
   ```dart
   try {
     // code
   } catch (e) {
     // Instead of: throw e;
     rethrow;
   }
   ```

## Running Analysis Locally

### Check all issues:
```bash
cd spike/graphics_performance_spike
flutter analyze
# or
dart analyze --fatal-warnings
```

### Check errors only:
```bash
cd spike/graphics_performance_spike
dart analyze
```

### Get detailed output:
```bash
cd spike/graphics_performance_spike
dart analyze --verbose
```

## Configuration Files

### `analysis_options.yaml`
```yaml
include: package:flutter_lints/flutter.yaml

linter:
  rules:
    # Custom overrides can be added here
    # avoid_print: false  # Uncomment to allow print statements
```

### `pubspec.yaml` (dev dependencies)
```yaml
dev_dependencies:
  flutter_lints: ^6.0.0  # Provides lint rules
  flutter_test:
    sdk: flutter
```

## Continuous Integration

When setting up CI/CD, ensure static analysis is run:

```yaml
# Example GitHub Actions step
- name: Run static analysis
  run: |
    cd spike/graphics_performance_spike
    flutter analyze --fatal-warnings
```

## Recommended Workflow

1. **Before starting new work**: Run `flutter analyze` to see current issues
2. **During development**: Fix any new issues you introduce
3. **Before committing**: Ensure your changes don't add new warnings
4. **Gradual cleanup**: Pick a few existing issues to fix in each PR

## Team Guidelines

- **New code**: Must pass static analysis without warnings
- **Existing code**: Clean up issues gradually, don't let them grow
- **Print statements**: Use proper logging in production code
- **Imports**: Remove unused imports immediately
- **Override annotations**: Always add @override for overridden members

---

*Last updated: 2025-08-09*
*Hook setup completed - see `/Users/ritchie/development/ghsender/.git/hooks/`*