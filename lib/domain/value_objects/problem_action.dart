import 'package:equatable/equatable.dart';

/// Action that can be performed to address a problem
class ProblemAction extends Equatable {
  /// Unique identifier for the action type
  final String id;
  
  /// Display label for the action button
  final String label;
  
  /// Type of action to perform
  final ProblemActionType type;
  
  /// Optional command or parameter for the action
  final String? command;
  
  /// Icon to display on the button
  final String? icon;

  const ProblemAction({
    required this.id,
    required this.label,
    required this.type,
    this.command,
    this.icon,
  });

  @override
  List<Object?> get props => [id, label, type, command, icon];
}

/// Types of actions that can be performed to resolve problems
enum ProblemActionType {
  /// Send a machine command (like homing, reset, etc.)
  machineCommand,
  /// Send a raw command/bytes to the controller
  rawCommand,
  /// Navigate to a specific UI panel
  navigate,
  /// Dismiss the problem
  dismiss,
}