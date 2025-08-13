import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:window_manager/window_manager.dart';
import 'bloc/bloc_exports.dart';
import 'ui/app/app_integration.dart';
import 'utils/logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize logging system
  AppLogger.initialize();

  // Configure window manager for desktop platforms
  await windowManager.ensureInitialized();

  WindowOptions windowOptions = const WindowOptions(
    size: Size(1400, 900),
    minimumSize: Size(800, 600),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
    title: 'ghsender',
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  // fonts are loaded from local assets
  GoogleFonts.config.allowRuntimeFetching = false;

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (context) => CncCommunicationBloc()),
        BlocProvider(create: (context) => FileManagerBloc()),
        BlocProvider(
          create: (context) => ProfileBloc()..add(const ProfileLoadRequested()),
        ),
        BlocProvider(create: (context) => ProblemsBloc()),
        BlocProvider(create: (context) => MachineControllerBloc()),
      ],
      child: MaterialApp(
        title: 'ghsender',
        theme: ThemeData(primarySwatch: Colors.blue),
        home: const AppIntegrationLayer(),
      ),
    );
  }
}
