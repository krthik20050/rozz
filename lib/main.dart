import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rozz/core/database/database_helper.dart';
import 'package:rozz/features/transactions/data/datasources/sms_parser.dart';
import 'package:rozz/features/transactions/data/datasources/transaction_local_datasource.dart';
import 'package:rozz/features/transactions/data/repositories/transaction_repository_impl.dart';
import 'package:rozz/features/transactions/data/models/transaction_model.dart';
import 'package:rozz/features/transactions/presentation/bloc/transaction_bloc.dart';
import 'package:rozz/features/mab/data/datasources/mab_local_datasource.dart';
import 'package:rozz/features/mab/data/repositories/mab_repository_impl.dart';
import 'package:rozz/features/mab/domain/usecases/calculate_mab.dart';
import 'package:rozz/features/mab/presentation/bloc/mab_bloc.dart';
import 'package:rozz/features/home/presentation/pages/home_page.dart';
import 'package:rozz/features/mab/presentation/pages/mab_page.dart';
import 'package:rozz/features/onboarding/presentation/pages/lock_screen.dart';
import 'package:rozz/core/services/workmanager_service.dart';
import 'package:rozz/core/services/node_service.dart';
import 'package:rozz/core/security/app_lock_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rozz/core/theme/colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize WorkManager
  await WorkmanagerService.initialize();
  // Initialize Node.js Engine
  await NodeService().startEngine();

  final databaseHelper = DatabaseHelper();
  final transactionLocalDatasource = TransactionLocalDatasourceImpl(databaseHelper);
  final transactionRepository = TransactionRepositoryImpl(transactionLocalDatasource);
  
  final mabLocalDatasource = MabLocalDatasourceImpl(databaseHelper);
  final mabRepository = MabRepositoryImpl(mabLocalDatasource);
  final calculateMab = CalculateMab();

  final smsParser = SmsParser();

  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => TransactionBloc(transactionRepository)..add(LoadTransactions()),
        ),
        BlocProvider(
          create: (context) => MabBloc(mabRepository, calculateMab)..add(LoadMabStatus(
            month: DateTime.now().month, 
            year: DateTime.now().year,
            now: DateTime.now(),
          )),
        ),
      ],
      child: RozzApp(smsParser: smsParser),
    ),
  );
}

class RozzApp extends StatefulWidget {
  final SmsParser smsParser;
  const RozzApp({super.key, required this.smsParser});

  @override
  State<RozzApp> createState() => _RozzAppState();
}

class _RozzAppState extends State<RozzApp> with WidgetsBindingObserver {
  final _appLockService = AppLockService();
  bool _isUnlocked = false;
  static const _channel = MethodChannel('com.rozz/sms');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupSmsListener();
  }

  void _setupSmsListener() {
    // Phase 2: Use NodeService for real-time parsing
    NodeService().onMessage.listen((event) {
      if (event['tag'] == 'sms_parsed' && mounted) {
        final Map<String, dynamic> data = Map<String, dynamic>.from(event['message']);
        final transaction = TransactionModel.fromNodeJson(data);
        context.read<TransactionBloc>().add(AddTransaction(transaction));

        final now = DateTime.now();
        context.read<MabBloc>().add(LoadMabStatus(month: now.month, year: now.year, now: now));
      }
    });

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onSmsReceived') {
        final Map<dynamic, dynamic> args = call.arguments;
        // Offload parsing to Node.js bridge
        NodeService().sendMessage('parse_sms', {
          'body': args['body'],
          'sender': args['sender']
        });
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _appLockService.onAppBackground();
    } else if (state == AppLifecycleState.resumed) {
      _appLockService.onAppForeground();
      if (_appLockService.isLocked) {
        setState(() {
          _isUnlocked = false;
        });
      }
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
      home: _isUnlocked 
          ? const MainScaffold() 
          : LockScreen(onAuthenticated: () {
              setState(() {
                _isUnlocked = true;
              });
            }),
    );
  }
}

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;
  final _pages = [
    const HomePage(),
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

