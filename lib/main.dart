import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:rozz/core/database/database_helper.dart';
import 'package:rozz/core/security/secure_storage_service.dart';
import 'package:rozz/core/services/ai_service.dart';
import 'package:rozz/core/services/transaction_sync_service.dart';
import 'package:rozz/core/services/workmanager_service.dart';
import 'package:rozz/core/theme/colors.dart';
import 'package:rozz/core/theme/typography.dart';
import 'package:rozz/features/chat/presentation/pages/chat_rozz_page.dart';
import 'package:rozz/features/home/presentation/pages/home_page.dart';
import 'package:rozz/features/insights/data/datasources/dismissed_subscription_local_datasource.dart';
import 'package:rozz/features/insights/data/datasources/sender_label_local_datasource.dart';
import 'package:rozz/features/insights/data/repositories/dismissed_subscription_repository_impl.dart';
import 'package:rozz/features/insights/data/repositories/sender_label_repository_impl.dart';
import 'package:rozz/features/insights/domain/usecases/compute_monthly_summary.dart';
import 'package:rozz/features/insights/domain/usecases/compute_recurring_income.dart';
import 'package:rozz/features/insights/domain/usecases/compute_subscriptions.dart';
import 'package:rozz/features/insights/domain/usecases/compute_upcoming_charges.dart';
import 'package:rozz/features/insights/domain/usecases/resolve_sender_identities.dart';
import 'package:rozz/features/insights/presentation/bloc/insights_bloc.dart';
import 'package:rozz/features/insights/presentation/pages/insights_page.dart';
import 'package:rozz/features/mab/data/datasources/mab_local_datasource.dart';
import 'package:rozz/features/mab/data/repositories/mab_repository_impl.dart';
import 'package:rozz/features/mab/domain/usecases/calculate_mab.dart';
import 'package:rozz/features/mab/presentation/bloc/mab_bloc.dart';
import 'package:rozz/features/mab/presentation/pages/mab_page.dart';
import 'package:rozz/features/monthly_review/presentation/bloc/monthly_review_bloc.dart';
import 'package:rozz/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:rozz/features/transactions/data/datasources/sms_parser.dart';
import 'package:rozz/features/transactions/data/datasources/transaction_local_datasource.dart';
import 'package:rozz/features/transactions/data/repositories/transaction_repository_impl.dart';
import 'package:rozz/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:rozz/features/transactions/presentation/bloc/transaction_bloc.dart';
import 'package:rozz/features/transactions/presentation/pages/activity_page.dart';
import 'package:rozz/shared/services/contact_resolver.dart';
import 'package:rozz/shared/widgets/bottom_nav_bar.dart';
import 'package:rozz/shared/widgets/offline_banner.dart';

/// Dev-only bootstrap: imports an API key from `files/ai_key.txt`
/// into secure storage on first launch, then deletes the file. The key never
/// appears in source — it lives only on the device. GROQ (gsk_...),
/// OpenRouter (sk-or-...) and Gemini (AIza...) keys are all accepted
/// (AiService auto-routes by prefix).
///
/// ponytail: on release builds the app-files dir isn't writable from outside,
/// so the key from the `--dart-define=GROQ_API_KEY=...` build flag is seeded
/// instead when nothing is stored. The key never ships in source (GitHub push
/// protection rejects it); pass the define when building. Settings can
/// override/clear it anytime.
const String defaultApiKey = String.fromEnvironment('GROQ_API_KEY');

Future<void> _importDevApiKey(SecureStorageService storage) async {
  try {
    // Android app-files dir for this package (matches the method-channel
    // package id already hardcoded below).
    final file = File('/data/data/com.rozz.rozz/files/ai_key.txt');
    if (await file.exists()) {
      final key = (await file.readAsString()).trim();
      if (key.isNotEmpty) {
        await storage.writeValue(AiService.apiKeyStorageKey, key);
        await file.delete();
        return;
      }
    }
    // No stored key yet: seed the build-time key so the AI brain works out of
    // the box. Settings overrides/clears it. Nothing to seed → leave it.
    final existing = await storage.readValue(AiService.apiKeyStorageKey);
    if ((existing == null || existing.isEmpty) && defaultApiKey.isNotEmpty) {
      await storage.writeValue(AiService.apiKeyStorageKey, defaultApiKey);
    }
  } catch (_) {
    // Never block startup on the bootstrap.
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Database Helper — NOT awaited here: it opens lazily on first use (blocs
  // fire after runApp and share the same lazy future), so the first frame is
  // never blocked on disk IO / migrations.
  final dbHelper = DatabaseHelper();

  final secureStorage = SecureStorageService();
  // One-time dev bootstrap: if no API key is stored yet, import it from a
  // file dropped into the app's files dir (adb push). The file is deleted
  // after import and never ships in source — the key lives only on the device.
  unawaited(_importDevApiKey(secureStorage));
  final aiService = AiService(secureStorage);
  final smsParser = SmsParser();
  final txnLocalDS = TransactionLocalDatasourceImpl(dbHelper);
  final txnRepo = TransactionRepositoryImpl(txnLocalDS);

  final mabLocalDS = MabLocalDatasourceImpl(dbHelper);
  final mabRepo = MabRepositoryImpl(mabLocalDS);

  final syncService = TransactionSyncService(
    txnRepo,
    dbHelper,
    smsParser,
  );

  // Background EOD Task Scheduling (Android WorkManager). Never block startup
  // on background plumbing.
  if (!kIsWeb && Platform.isAndroid) {
    unawaited(WorkmanagerService.initialize().catchError((Object e) {
      debugPrint('WorkManager init failed: $e');
    }));
  }

  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider<TransactionBloc>(
          create: (context) => TransactionBloc(txnRepo, aiService)..add(LoadTransactions()),
        ),
        BlocProvider<MabBloc>(
          create: (context) => MabBloc(
            mabRepo,
            CalculateMab(),
            txnRepo,
            secureStorage,
          )..add(LoadMabStatus(
            month: DateTime.now().month,
            year: DateTime.now().year,
            now: DateTime.now(),
          )),
        ),
        BlocProvider<InsightsBloc>(
          create: (context) => InsightsBloc(
            txnRepo,
            SenderLabelRepositoryImpl(
              SenderLabelLocalDatasourceImpl(dbHelper),
            ),
            DismissedSubscriptionRepositoryImpl(
              DismissedSubscriptionLocalDatasourceImpl(dbHelper),
            ),
            ContactResolver(),
            ComputeMonthlySummary(),
            ComputeSubscriptions(),
            ComputeUpcomingCharges(),
            ResolveSenderIdentities(),
            ComputeRecurringIncome(),
          )..add(LoadInsights(now: DateTime.now())),
        ),
        BlocProvider<MonthlyReviewBloc>(
          create: (context) => MonthlyReviewBloc(
            txnRepo,
            ComputeMonthlySummary(),
          ),
        ),
      ],
      child: RozzApp(
        syncService: syncService,
        secureStorage: secureStorage,
        aiService: aiService,
        transactionRepository: txnRepo,
      ),
    ),
  );
}

class RozzApp extends StatefulWidget {
  final TransactionSyncService syncService;
  final SecureStorageService secureStorage;
  final AiService aiService;
  final TransactionRepository transactionRepository;
  const RozzApp({
    super.key,
    required this.syncService,
    required this.secureStorage,
    required this.aiService,
    required this.transactionRepository,
  });

  @override
  State<RozzApp> createState() => _RozzAppState();
}

class _RozzAppState extends State<RozzApp> {
  static const _onboardingDoneKey = 'onboarding_complete';

  bool _isSyncing = false;
  double _syncProgress = 0.0;
  String _syncStatus = "Initializing...";
  static const _channel = MethodChannel('com.rozz/sms');

  bool _flagLoaded = false;
  bool _showOnboarding = false;

  /// Whether ROZZ's notification listener is active. MIUI silently drops the
  /// bind on reboot/update, so this is re-checked on every launch and surfaced
  /// on the home page as a warning card when missing.
  bool _notificationAccess = true;

  @override
  void initState() {
    super.initState();
    _setupSmsListener();
    _loadOnboardingFlag();
  }

  /// First-run users see the onboarding walkthrough (which explains the *why*
  /// for permissions) before any permission is requested. Returning users go
  /// straight to the existing auto-start workflow.
  Future<void> _loadOnboardingFlag() async {
    final done = await widget.secureStorage.readValue(_onboardingDoneKey);
    if (!mounted) return;
    setState(() {
      _flagLoaded = true;
      _showOnboarding = done != 'true';
    });
    if (done == 'true') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _autoStartWorkflow();
      });
    }
  }

  Future<void> _finishOnboarding() async {
    await widget.secureStorage.writeValue(_onboardingDoneKey, 'true');
    if (!mounted) return;
    setState(() => _showOnboarding = false);
    // The walkthrough's last screen just explained why this permission is
    // needed — request it now, in context.
    await _autoStartWorkflow();
  }

  Future<void> _autoStartWorkflow() async {
    if (kIsWeb || !Platform.isAndroid) {
      await _loadMockData();
      return;
    }

    var status = await Permission.sms.status;
    if (!status.isGranted) {
      status = await Permission.sms.request();
    }

    final notifStatus = await Permission.notification.status;
    if (!notifStatus.isGranted) {
      await Permission.notification.request();
    }

    if (status.isGranted) {
      // Live capture = notification listener. MIUI drops the bind on
      // reboot/update, so re-check after opening settings AND surface the
      // result on the home page instead of silently running deaf.
      var hasAccess =
          await _channel.invokeMethod<bool>('isNotificationAccessGranted') ?? false;
      if (!hasAccess) {
        await _channel.invokeMethod('openNotificationAccessSettings');
        hasAccess =
            await _channel.invokeMethod<bool>('isNotificationAccessGranted') ?? false;
      }
      if (mounted && !hasAccess) {
        setState(() => _notificationAccess = false);
      }

      final count = await widget.syncService.transactionCount();
      if (count == 0) {
        // First run: nothing in the ledger yet — do the full backfill with the
        // progress screen.
        await syncInbox();
      } else {
        // Already synced: fast incremental drain of whatever the native
        // listener captured. The heavy inbox backfill runs in the background
        // (WorkManager smsBackfillTask), not on every app open.
        final pending = await widget.syncService.drainPendingSms();
        final raw = await widget.syncService.drainRawInbox();
        // Nothing new landed — don't re-run every screen's heavy load for
        // nothing.
        if (pending + raw > 0) {
          _refreshAllBlocs();
        }
      }
    }
  }

  /// Re-pull every screen from the (just updated) local ledger.
  void _refreshAllBlocs() {
    if (!mounted) return;
    context.read<TransactionBloc>().add(LoadTransactions());
    final now = DateTime.now();
    context.read<MabBloc>().add(LoadMabStatus(month: now.month, year: now.year, now: now));
    context.read<InsightsBloc>().add(LoadInsights(now: now));
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
          _syncStatus = "Parsed $drained messages, drained $fromInbox + $pending pending...";
          _syncProgress = 0.9;
        });
        _refreshAllBlocs();
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
          final drained = await widget.syncService.drainPendingSms();
          if (drained > 0 && mounted) {
            context.read<TransactionBloc>().add(LoadTransactions());
            final now = DateTime.now();
            context.read<MabBloc>().add(LoadMabStatus(month: now.month, year: now.year, now: now));
            context.read<InsightsBloc>().add(LoadInsights(now: now));
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
        textTheme: RozzTypography.textTheme,
      ),
      home: !_flagLoaded
          ? const _SplashPage()
          : _showOnboarding
              ? OnboardingPage(onDone: _finishOnboarding)                  : _isSyncing
                      ? _SyncLoadingPage(status: _syncStatus, progress: _syncProgress)
                      : MainScaffold(
                          onSync: syncInbox,
                          notificationAccess: _notificationAccess,
                          onEnableNotificationAccess: () async {
                            await _channel.invokeMethod('openNotificationAccessSettings');
                            final ok = await _channel
                                    .invokeMethod<bool>('isNotificationAccessGranted') ??
                                false;
                            if (mounted) {
                              setState(() => _notificationAccess = ok);
                            }
                          },
aiService: widget.aiService,
                          secureStorage: widget.secureStorage,
                          syncService: widget.syncService,
                          transactionRepository: widget.transactionRepository,
                        ),
    );
  }
}

/// A momentary branded frame while the onboarding flag loads from secure
/// storage (a few ms — prevents any flash of the wrong screen).
class _SplashPage extends StatelessWidget {
  const _SplashPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: RozzColors.bg,
      body: Center(
        child: Text(
          'ROZZ',
          style: TextStyle(
            color: RozzColors.gold,
            fontSize: 32,
            fontWeight: FontWeight.bold,
            letterSpacing: 4,
          ),
        ),
      ),
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
              Text(
                'ROZZ',
                style: RozzTypography.financialNumber(
                  fontSize: 36,
                  color: RozzColors.gold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'your bank balance, finally understood.',
                style: RozzTypography.textTheme.bodyMedium?.copyWith(
                  color: RozzColors.textSecondary,
                ),
              ),
              const SizedBox(height: 48),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: RozzColors.s1,
                  valueColor: const AlwaysStoppedAnimation<Color>(RozzColors.gold),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                status,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: RozzColors.textSecondary,
                  fontSize: 13,
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

  /// Whether the notification listener is bound (surfaced on the home page).
  final bool notificationAccess;
  final VoidCallback? onEnableNotificationAccess;

  final AiService aiService;
  final SecureStorageService secureStorage;
  final TransactionSyncService syncService;
  final TransactionRepository transactionRepository;
  const MainScaffold({
    super.key,
    required this.onSync,
    this.notificationAccess = true,
    this.onEnableNotificationAccess,
    required this.aiService,
    required this.secureStorage,
    required this.syncService,
    required this.transactionRepository,
  });

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;
  String? _accountSuffix;

  @override
  void initState() {
    super.initState();
    // The real account suffix ("4736") derived from the bank SMS.
    widget.syncService.accountSuffix().then((suffix) {
      if (mounted && suffix != null) {
        setState(() => _accountSuffix = suffix);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(
        onSync: widget.onSync,
        accountSuffix: _accountSuffix,
        notificationAccess: widget.notificationAccess,
        onEnableNotificationAccess: widget.onEnableNotificationAccess,
      ),
      const ActivityPage(),
      ChatRozzPage(
        aiService: widget.aiService,
        secureStorage: widget.secureStorage,
        transactionRepository: widget.transactionRepository,
        // "Close" on the chat means back to the home tab — the chat lives in
        // the IndexedStack and was never pushed, so popping would exit the app.
        onClose: () => setState(() => _currentIndex = 0),
      ),
      const InsightsPage(),
      const MabPage(),
    ];

    // Back goes home first (never a surprise exit): on any tab other than
    // home, the system back button lands on home; only home lets it exit.
    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) setState(() => _currentIndex = 0);
      },
      child: Scaffold(
        body: Stack(
          children: [
            IndexedStack(index: _currentIndex, children: pages),
            // Offline notice slides in at the top, above all tabs.
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: OfflineBanner(),
            ),
          ],
        ),
        // Bar is always visible (chat included): the Scaffold insets the body
        // above it, so the chat page's own input bar never overlaps.
        bottomNavigationBar: SafeArea(
          top: false,
          child: BottomNavBar(
            currentIndex: _currentIndex,
            onTapTab: (index) => setState(() => _currentIndex = index),
          ),
        ),
      ),
    );
  }
}