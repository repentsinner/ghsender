import 'package:equatable/equatable.dart';
import '../../models/problem.dart';

/// State for the Problems BLoC
class ProblemsState extends Equatable {
  /// List of all current problems
  final List<Problem> problems;
  
  /// Whether the problems system is initialized
  final bool isInitialized;
  
  const ProblemsState({
    this.problems = const [],
    this.isInitialized = false,
  });
  
  /// Create a copy with updated fields
  ProblemsState copyWith({
    List<Problem>? problems,
    bool? isInitialized,
  }) {
    return ProblemsState(
      problems: problems ?? this.problems,
      isInitialized: isInitialized ?? this.isInitialized,
    );
  }
  
  /// Get all problems with error severity
  List<Problem> get errors => problems
      .where((p) => p.severity == ProblemSeverity.error)
      .toList();
  
  /// Get all problems with warning severity
  List<Problem> get warnings => problems
      .where((p) => p.severity == ProblemSeverity.warning)
      .toList();
  
  /// Get all problems with info severity
  List<Problem> get infos => problems
      .where((p) => p.severity == ProblemSeverity.info)
      .toList();
  
  /// Get count of problems by severity
  int get errorCount => errors.length;
  int get warningCount => warnings.length;
  int get infoCount => infos.length;
  
  /// Get total count of all problems
  int get totalCount => problems.length;
  
  /// Check if there are any problems
  bool get hasProblems => problems.isNotEmpty;
  
  /// Check if there are any errors
  bool get hasErrors => errorCount > 0;
  
  /// Check if there are any warnings
  bool get hasWarnings => warningCount > 0;
  
  /// Get problems sorted by priority (errors first, then warnings, then info)
  /// Within each severity level, sort by timestamp (newest first)
  List<Problem> get sortedProblems {
    final sorted = List<Problem>.from(problems);
    sorted.sort((a, b) {
      // First sort by severity priority (higher = more important)
      final priorityComparison = b.severity.priority.compareTo(a.severity.priority);
      if (priorityComparison != 0) return priorityComparison;
      
      // Then sort by timestamp (newest first)
      return b.timestamp.compareTo(a.timestamp);
    });
    return sorted;
  }
  
  /// Get problems from a specific source
  List<Problem> getProblemsForSource(String source) {
    return problems.where((p) => p.source == source).toList();
  }
  
  /// Check if a specific problem ID exists
  bool hasProblem(String problemId) {
    return problems.any((p) => p.id == problemId);
  }
  
  /// Get a specific problem by ID
  Problem? getProblem(String problemId) {
    try {
      return problems.firstWhere((p) => p.id == problemId);
    } catch (e) {
      return null;
    }
  }
  
  /// Get summary text for display
  String get summaryText {
    if (!hasProblems) return 'No problems detected';
    
    final parts = <String>[];
    if (hasErrors) {
      parts.add('$errorCount error${errorCount == 1 ? '' : 's'}');
    }
    if (hasWarnings) {
      parts.add('$warningCount warning${warningCount == 1 ? '' : 's'}');
    }
    if (infoCount > 0) {
      parts.add('$infoCount info');
    }
    
    return parts.join(', ');
  }
  
  /// Get icon for current state
  String get statusIcon {
    if (hasErrors) return '❌';
    if (hasWarnings) return '⚠️';
    if (infoCount > 0) return 'ℹ️';
    return '✅';
  }
  
  @override
  List<Object?> get props => [problems, isInitialized];
  
  @override
  String toString() {
    return 'ProblemsState{problems: ${problems.length}, initialized: $isInitialized, '
        'errors: $errorCount, warnings: $warningCount, infos: $infoCount}';
  }
}