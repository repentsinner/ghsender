import 'package:flutter/material.dart';
import 'dart:async';

import '../../utils/logger.dart';
import '../../bloc/bloc_exports.dart';
import '../screens/grblhal_visualizer.dart';

/// App Integration Layer - handles BLoC communication and state integration
/// Manages profile integration, communication monitoring, and machine detection
class AppIntegrationLayer extends StatefulWidget {
  const AppIntegrationLayer({super.key});

  @override
  State<AppIntegrationLayer> createState() => _AppIntegrationLayerState();
}

class _AppIntegrationLayerState extends State<AppIntegrationLayer> {
  Timer? _grblHalDetectionTimeout;

  @override
  void dispose() {
    _grblHalDetectionTimeout?.cancel();
    super.dispose();
  }

  /// Schedule timeout for grblHAL detection after connection
  void _scheduleGrblHalDetectionTimeout(BuildContext context) {
    // Cancel any existing timeout
    _grblHalDetectionTimeout?.cancel();
    
    // Wait 3 seconds for grblHAL welcome message - if not found, disconnect
    _grblHalDetectionTimeout = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        final machineState = context.read<MachineControllerBloc>().state;
        
        if (!machineState.grblHalDetected) {
          AppLogger.error('grblHAL not detected - this sender requires grblHAL firmware');
          
          // Disconnect since we only support grblHAL
          context.read<CncCommunicationBloc>().add(
            CncCommunicationDisconnectRequested(),
          );
          
          // Show error in machine controller
          context.read<MachineControllerBloc>().add(
            MachineControllerInfoUpdated(
              firmwareVersion: 'ERROR: grblHAL required - Standard GRBL not supported',
            ),
          );
        }
      }
    });
  }

  @override
  void initState() {
    super.initState();
    // Trigger initial state analysis after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _triggerInitialStateAnalysis();
    });
  }

  /// Initialize BLoC connections and trigger initial state analysis
  void _triggerInitialStateAnalysis() {
    final profileBloc = context.read<ProfileBloc>();
    final commBloc = context.read<CncCommunicationBloc>();
    final fileBloc = context.read<FileManagerBloc>();
    final problemsBloc = context.read<ProblemsBloc>();
    final machineBloc = context.read<MachineControllerBloc>();
    
    AppLogger.info('Triggering initial state analysis for all BLoCs');
    
    // Set up communication bloc reference in machine controller
    machineBloc.add(MachineControllerSetCommunicationBloc(commBloc));
    
    // Analyze current states
    problemsBloc.add(ProfileStateAnalyzed(profileBloc.state));
    problemsBloc.add(CncCommunicationStateAnalyzed(commBloc.state));
    problemsBloc.add(FileManagerStateAnalyzed(fileBloc.state));
    problemsBloc.add(MachineControllerStateAnalyzed(machineBloc.state));
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        // Profile state integration
        BlocListener<ProfileBloc, ProfileState>(
          listener: (context, profileState) {
            // When profile is loaded or changed, configure the CNC communication controller address
            if (profileState is ProfileLoaded) {
              final profile = profileState.currentProfile;
              AppLogger.info(
                'Profile loaded/changed: ${profile.name}, setting controller address: ${profile.controllerAddress}',
              );

              context.read<CncCommunicationBloc>().add(
                CncCommunicationSetControllerAddress(profile.controllerAddress),
              );
            }
            
            // Monitor profile state for problems
            context.read<ProblemsBloc>().add(
              ProfileStateAnalyzed(profileState),
            );
          },
        ),
        
        // CNC Communication state monitoring
        BlocListener<CncCommunicationBloc, CncCommunicationState>(
          listener: (context, commState) {
            // Reduced logging - only log important state changes
            
            // Send to Problems BLoC for problem analysis
            context.read<ProblemsBloc>().add(
              CncCommunicationStateAnalyzed(commState),
            );
            
            // Send to Machine Controller BLoC for machine state processing
            context.read<MachineControllerBloc>().add(
              MachineControllerCommunicationReceived(commState),
            );
            
            // Handle initial connection - wait for grblHAL detection
            if (commState is CncCommunicationConnected) {
              AppLogger.info('Connection established, waiting for grblHAL welcome message');
              
              // Wait for grblHAL detection - disconnect if not found
              _scheduleGrblHalDetectionTimeout(context);
            }
            
            // Stop timers when disconnected
            if (commState is CncCommunicationDisconnected || 
                commState is CncCommunicationError ||
                commState is CncCommunicationInitial) {
              AppLogger.info('Connection lost, stopping timers');
              _grblHalDetectionTimeout?.cancel();
              _grblHalDetectionTimeout = null;
            }
          },
        ),
        
        // File Manager state monitoring
        BlocListener<FileManagerBloc, FileManagerState>(
          listener: (context, fileState) {
            AppLogger.debug('File manager state changed');
            context.read<ProblemsBloc>().add(
              FileManagerStateAnalyzed(fileState),
            );
          },
        ),
        
        // Machine Controller state monitoring
        BlocListener<MachineControllerBloc, MachineControllerState>(
          listener: (context, machineState) {
            // Cancel timeout when grblHAL is detected
            if (machineState.grblHalDetected) {
              _grblHalDetectionTimeout?.cancel();
              _grblHalDetectionTimeout = null;
            }
            
            // Send machine state to Problems BLoC for analysis
            context.read<ProblemsBloc>().add(
              MachineControllerStateAnalyzed(machineState),
            );
          },
        ),
      ],
      child: const GrblHalVisualizerScreen(),
    );
  }
}