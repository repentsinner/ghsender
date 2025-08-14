import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../utils/logger.dart';
import '../../bloc/bloc_exports.dart';
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
          listener: (context, machineState) {
            // Send machine state to Problems BLoC for analysis
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