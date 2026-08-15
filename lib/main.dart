import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:rozz/core/database/database_helper.dart';
import 'package:rozz/features/transactions/data/datasources/sms_parser.dart';
import 'package:rozz/features/transactions/data/datasources/transaction_local_datasource.dart';
import 'package:rozz/features/transactions/data/repositories/transaction_repository_impl.dart';
import 'package:rozz/features/transactions/presentation/bloc/transaction_bloc.dart';
import 'package:rozz/features/mab/data/datasources/mab_local_datasource.dart';
import 'package:rozz/features/mab/data/repositories/mab_repository_impl.dart';
import 'package:rozz/features/mab/domain/usecases/calculate_mab.dart';
import 'package:rozz/features/mab/presentation/bloc/mab_bloc.dart';
import 'package:rozz/features/home/presentation/pages/home_page.dart';
import 'package:rozz/features/mab/presentation/pages/mab_page.dart';
import 'package:rozz/core/services/workmanager_service.dart';
import 'package:rozz/core/services/transaction_sync_service.dart';
import 'package:rozz/core/services/gemini_service.dart';
import 'package:rozz/core/security/secure_storage_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rozz/core/theme/colors.dart';
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SQLite for Desktop
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Initialize WorkManager (Android only)
  if (!kIsWeb && Platform.isAndroid) {
    await WorkmanagerService.initialize();
  }

  final databaseHelper = DatabaseHelper();
  final transactionLocalDatasource = TransactionLocalDatasourceImpl(databaseHelper);
  final transactionRepository = TransactionRepositoryImpl(transactionLocalDatasource);

  final mabLocalDatasource = MabLocalDatasourceImpl(databaseHelper);
  final mabRepository = MabRepositoryImpl(mabLocalDatasource);
  final calculateMab = CalculateMab();

  final smsParser = SmsParser();
  final syncService = TransactionSyncService(transactionRepository, databaseHelper, smsParser);
  final geminiService = GeminiService(SecureStorageService());

  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => TransactionBloc(transactionRepository, geminiService)..add(LoadTransactions()),
        ),
        BlocProvider(
          create: (context) => MabBloc(mabRepository, calculateMab, transactionRepository)..add(LoadMabStatus(
            month: DateTime.now().month,
            year: DateTime.now().year,
            now: DateTime.now(),
          )),
        ),
      ],
      child: RozzApp(syncService: syncService),
    ),
  );
}

class RozzApp extends StatefulWidget {
  final TransactionSyncService syncService;
  const RozzApp({super.key, required this.syncService});

  @override
  State<RozzApp> createState() => _RozzAppState();
}

class _RozzAppState extends State<RozzApp> {
  bool _isSyncing = false;
  double _syncProgress = 0.0;
  String _syncStatus = "Initializing...";
  static const _channel = MethodChannel('com.rozz/sms');

  @override
  void initState() {
    super.initState();
    _setupSmsListener();
    // Auto-start the workflow after initial frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoStartWorkflow();
    });
  }

  Future<void> _autoStartWorkflow() async {
    if (kIsWeb || !Platform.isAndroid) {
      await _loadMockData();
      return;
    }

    // 1. Request Permissions
    var status = await Permission.sms.status;
    if (!status.isGranted) {
      status = await Permission.sms.request();
    }

    // Foreground-service notification (Android 13+): needed for the persistent
    // "ROZZ is monitoring" notification that keeps background capture alive.
    final notifStatus = await Permission.notification.status;
    if (!notifStatus.isGranted) {
      await Permission.notification.request();
    }

    if (status.isGranted) {
      // 2. Notification access (Android 13+ primary capture path) — deep-link once if off
      final hasAccess = await _channel.invokeMethod<bool>('isNotificationAccessGranted') ?? false;
      if (!hasAccess) {
        await _channel.invokeMethod('openNotificationAccessSettings');
      }
      // 3. Trigger Auto-Sync
      await syncInbox();
    }
  }

  Future<void> _loadMockData() async {
    if (!mounted) return;
    setState(() {
      _isSyncing = true;
      _syncStatus = "Loading Mock Data...";
      _syncProgress = 0.1;
    });

    try {
      final String response = await rootBundle.loadString('assets/mock_sms.json');
      final List<dynamic> messages = jsonDecode(response);
      final total = messages.length;

      if (!mounted) return;
      setState(() {
        _syncStatus = "Parsing $total Mock Messages...";
        _syncProgress = 0.2;
      });

      int processed = 0;
      for (final msg in messages) {
        final Map<String, dynamic> sms = Map<String, dynamic>.from(msg);
        await widget.syncService.ingestSms(sms);

        processed++;
        if (processed % 5 == 0 && mounted) {
          setState(() {
            _syncProgress = 0.2 + (0.7 * (processed / total));
          });
          await Future.delayed(const Duration(milliseconds: 50));
        }
      }

      if (mounted) {
        setState(() {
          _syncStatus = "Finalizing...";
          _syncProgress = 0.95;
        });
      }
      await Future.delayed(const Duration(seconds: 1));
    } catch (e) {
      debugPrint('Mock Data Error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
          _syncProgress = 1.0;
        });
      }
    }
  }

  Future<void> syncInbox() async {
    if (_isSyncing) return;

    if (mounted) {
      setState(() {
        _isSyncing = true;
        _syncStatus = "Scanning Inbox...";
        _syncProgress = 0.1;
      });
    }

    try {
      final drained = await widget.syncService.backfillInbox();
      final fromInbox = await widget.syncService.drainRawInbox();
      final pending = await widget.syncService.drainPendingSms();

      if (mounted) {
        setState(() {
          _syncStatus =
              "Parsed $drained messages, drained $fromInbox + $pending pending...";
          _syncProgress = 0.9;
        });
        context.read<TransactionBloc>().add(LoadTransactions());
        final now = DateTime.now();
        context.read<MabBloc>().add(LoadMabStatus(month: now.month, year: now.year, now: now));
      }
    } catch (e) {
      debugPrint('Sync Error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
          _syncProgress = 1.0;
        });
      }
    }
  }

  void _setupSmsListener() {
    if (!kIsWeb && Platform.isAndroid) {
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'onSmsReceived') {
          // Native already appended the SMS to the JSONL handoff; drain parses + inserts.
          final drained = await widget.syncService.drainPendingSms();
          if (drained > 0 && mounted) {
            context.read<TransactionBloc>().add(LoadTransactions());
            final now = DateTime.now();
            context.read<MabBloc>().add(LoadMabStatus(month: now.month, year: now.year, now: now));
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ROZZ',
      theme: ThemeData(
        scaffoldBackgroundColor: RozzColors.bg,
        textTheme: GoogleFonts.dmSansTextTheme(
          ThemeData.dark().textTheme,
        ),
      ),
      home: _isSyncing
        ? _SyncLoadingPage(status: _syncStatus, progress: _syncProgress)
        : MainScaffold(onSync: syncInbox),
    );
  }
}

class _SyncLoadingPage extends StatelessWidget {
  final String status;
  final double progress;

  const _SyncLoadingPage({required this.status, required this.progress});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RozzColors.bg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'ROZZ',
                style: TextStyle(
                  color: RozzColors.accent,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 8,
                ),
              ),
              const SizedBox(height: 48),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: RozzColors.s1,
                valueColor: const AlwaysStoppedAnimation<Color>(RozzColors.accent),
              ),
              const SizedBox(height: 24),
              Text(
                status,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: RozzColors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MainScaffold extends StatefulWidget {
  final VoidCallback onSync;
  const MainScaffold({super.key, required this.onSync});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;
  late final _pages = [
    HomePage(onSync: widget.onSync),
    const MabPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        backgroundColor: RozzColors.s1,
        selectedItemColor: RozzColors.accent,
        unselectedItemColor: RozzColors.textSecondary,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.shield_outlined), label: ''),
        ],
      ),
    );
  }
}