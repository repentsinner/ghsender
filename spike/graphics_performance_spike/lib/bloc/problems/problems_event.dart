import 'package:equatable/equatable.dart';
import '../../models/problem.dart';
import '../../bloc/communication/cnc_communication_state.dart';
import '../../bloc/file_manager/file_manager_state.dart';
import '../../bloc/profile/profile_state.dart';

/// Events for the Problems BLoC
abstract class ProblemsEvent extends Equatable {
  const ProblemsEvent();
  
  @override
  List<Object?> get props => [];
}

/// Add a new problem to the list
class ProblemAdded extends ProblemsEvent {
  final Problem problem;
  
  const ProblemAdded(this.problem);
  
  @override
  List<Object?> get props => [problem];
}

/// Remove a specific problem by ID
class ProblemRemoved extends ProblemsEvent {
  final String problemId;
  
  const ProblemRemoved(this.problemId);
  
  @override
  List<Object?> get props => [problemId];
}

/// Update an existing problem (e.g., change severity or description)
class ProblemUpdated extends ProblemsEvent {
  final Problem problem;
  
  const ProblemUpdated(this.problem);
  
  @override
  List<Object?> get props => [problem];
}

/// Clear all problems (useful for reset scenarios)
class ProblemsCleared extends ProblemsEvent {
  const ProblemsCleared();
}

/// Initialize the Problems BLoC state
class ProblemsInitialized extends ProblemsEvent {
  const ProblemsInitialized();
}

/// Clear all problems from a specific source
class ProblemsClearedForSource extends ProblemsEvent {
  final String source;
  
  const ProblemsClearedForSource(this.source);
  
  @override
  List<Object?> get props => [source];
}

/// Analysis events for monitoring other BLoC states
/// These events trigger problem analysis based on state changes

/// Analyze CNC Communication state for problems
class CncCommunicationStateAnalyzed extends ProblemsEvent {
  final CncCommunicationState state;
  
  const CncCommunicationStateAnalyzed(this.state);
  
  @override
  List<Object?> get props => [state];
}

/// Analyze File Manager state for problems
class FileManagerStateAnalyzed extends ProblemsEvent {
  final FileManagerState state;
  
  const FileManagerStateAnalyzed(this.state);
  
  @override
  List<Object?> get props => [state];
}

/// Analyze Profile state for problems
class ProfileStateAnalyzed extends ProblemsEvent {
  final ProfileState state;
  
  const ProfileStateAnalyzed(this.state);
  
  @override
  List<Object?> get props => [state];
}

/// Note: Removed ProblemsStaleCleanup event
/// Problems no longer automatically expire - they persist until resolved