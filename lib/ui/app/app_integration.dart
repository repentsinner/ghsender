import 'package:flutter/material.dart';

import '../../utils/logger.dart';
import '../../bloc/bloc_exports.dart';
import '../../bloc/alarm_error/alarm_error_bloc.dart';
import '../../bloc/alarm_error/alarm_error_event.dart';
import '../../bloc/alarm_error/alarm_error_state.dart';
import '../../bloc/performance/performance_bloc.dart';
import '../../bloc/graphics/graphics_bloc.dart';
import '../screens/grblhal_visualizer.dart';

/// App Integration Layer - handles BLoC communication and state integration
/// Manages profile integration, communication monitoring, and state coordination
class AppIntegrationLayer extends StatefulWidget {
  const AppIntegrationLayer({super.key});

  @override
  State<AppIntegrationLayer> createState() => _AppIntegrationLayerState();
}

class _AppIntegrationLayerState extends State<AppIntegrationLayer> {

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
    final settingsBloc = context.read<SettingsBloc>();
    final alarmErrorBloc = context.read<AlarmErrorBloc>();
    
    AppLogger.info('Triggering initial state analysis for all BLoCs');
    
    // Set up communication bloc references
    machineBloc.add(MachineControllerSetCommunicationBloc(commBloc));
    machineBloc.add(MachineControllerSetAlarmErrorBloc(alarmErrorBloc));
    settingsBloc.add(SettingsSetCommunicationBloc(commBloc));
    alarmErrorBloc.add(AlarmErrorSetCommunicationBloc(commBloc));
    
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
          listenWhen: (previous, current) {
            // Only listen on actual connection state changes, not performance updates
            return previous.runtimeType != current.runtimeType;
          },
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
            
            // Log connection establishment
            if (commState is CncCommunicationConnected) {
              AppLogger.info('Connection established - machine controller will handle grblHAL detection');
            }
            
            // Log disconnection
            if (commState is CncCommunicationDisconnected || 
                commState is CncCommunicationError ||
                commState is CncCommunicationInitial) {
              AppLogger.info('Connection lost');
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
          listenWhen: (previous, current) {
            // Always process the first time we get a controller
            if (previous.hasController != current.hasController && current.hasController) {
              AppLogger.debug('ProblemsBloc triggered - first controller connection');
              return true;
            }
            
            // Always process when grblHAL detection changes
            if (previous.grblHalDetected != current.grblHalDetected) {
              AppLogger.debug('ProblemsBloc triggered - grblHAL detection changed');
              return true;
            }

            
            // Only analyze for problems when machine state actually changes
            // (not on position updates, feed rate changes, etc.)
            final shouldListen = previous.status != current.status ||
                   previous.hasAlarms != current.hasAlarms ||
                   previous.hasErrors != current.hasErrors ||
                   previous.hasActiveAlarmConditions != current.hasActiveAlarmConditions ||
                   previous.hasActiveErrorConditions != current.hasActiveErrorConditions ||
                   previous.isOnline != current.isOnline;
            
            // Debug logging to understand filtering
            if (shouldListen) {
              AppLogger.debug('ProblemsBloc triggered - status: ${current.status.name}, alarms: ${current.hasAlarms}, activeAlarms: ${current.hasActiveAlarmConditions}');
            }
            
            return shouldListen;
          },
          listener: (context, machineState) {
            // Send machine state to Problems BLoC for analysis
            context.read<ProblemsBloc>().add(
              MachineControllerStateAnalyzed(machineState),
            );
            
            // Context info requests moved to MachineController._configureGrblHalReporting()
            // for immediate availability regardless of alarm/error state
          },
        ),

        // AlarmError metadata monitoring - re-analyze problems when metadata loads
        BlocListener<AlarmErrorBloc, AlarmErrorState>(
          listenWhen: (previous, current) {
            // Re-analyze problems when alarm/error metadata becomes available
            return previous.alarmMetadataLoaded != current.alarmMetadataLoaded ||
                   previous.errorMetadataLoaded != current.errorMetadataLoaded;
          },
          listener: (context, alarmErrorState) {
            AppLogger.debug('AlarmError metadata loaded - re-analyzing machine problems for enhanced display');
            final machineState = context.read<MachineControllerBloc>().state;
            context.read<ProblemsBloc>().add(
              MachineControllerStateAnalyzed(machineState),
            );
          },
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<PerformanceBloc>(
            create: (_) => PerformanceBloc(),
          ),
          BlocProvider<GraphicsBloc>(
            create: (_) => GraphicsBloc(),
          ),
        ],
        child: const GrblHalVisualizerScreen(),
      ),
    );
  }
}