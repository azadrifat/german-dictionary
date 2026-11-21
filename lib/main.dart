import 'package:flutter/material.dart';

import 'data.dart';
import 'screens.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DictApp());
}

const Color _seed = Color(0xFF1F6F5C); // deep green

ThemeData _theme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(seedColor: _seed, brightness: brightness);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      scrolledUnderElevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: BorderSide.none,
      ),
    ),
    chipTheme: const ChipThemeData(
      shape: StadiumBorder(),
      side: BorderSide.none,
    ),
  );
}

class DictApp extends StatelessWidget {
  const DictApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: kAppName,
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: const Boot(),
    );
  }
}

/// Checks for the dictionary data on first launch and downloads it if needed.
class Boot extends StatefulWidget {
  const Boot({super.key});

  @override
  State<Boot> createState() => _BootState();
}

class _BootState extends State<Boot> {
  String _state = 'loading'; // loading, needs, downloading, ready, error
  double? _progress;
  String _message = '';
  String _error = '';

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    setState(() => _state = 'loading');
    try {
      await store.init();
      if (await store.hasDb()) {
        await store.openDb();
        if (mounted) setState(() => _state = 'ready');
      } else {
        if (mounted) setState(() => _state = 'needs');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = 'error';
          _error = '$e';
        });
      }
    }
  }

  Future<void> _download() async {
    setState(() {
      _state = 'downloading';
      _progress = null;
      _message = 'Starting...';
    });
    try {
      await store.download((fraction, message) {
        if (mounted) {
          setState(() {
            _progress = fraction;
            _message = message;
          });
        }
      });
      await store.openDb();
      if (mounted) setState(() => _state = 'ready');
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = 'error';
          _error = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_state == 'ready') return const HomeScreen();

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    Widget body;
    switch (_state) {
      case 'needs':
        body = Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(32),
              ),
              child: Icon(Icons.menu_book_rounded,
                  size: 56, color: scheme.onPrimaryContainer),
            ),
            const SizedBox(height: 24),
            Text(kAppName, style: theme.textTheme.headlineLarge),
            const SizedBox(height: 12),
            Text(
              'The dictionary data has to be downloaded once: about 30 MB to '
              'download, about 110 MB on your phone. Please use Wi-Fi.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: _download,
              icon: const Icon(Icons.download_rounded),
              label: const Text('Download'),
            ),
          ],
        );
        break;
      case 'downloading':
        body = Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Preparing the dictionary', style: theme.textTheme.titleLarge),
            const SizedBox(height: 24),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(value: _progress, minHeight: 8),
            ),
            const SizedBox(height: 12),
            Text(_message),
          ],
        );
        break;
      case 'error':
        body = Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, size: 56, color: scheme.error),
            const SizedBox(height: 16),
            Text('Something went wrong', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            Text(_error, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton.tonal(
              onPressed: _start,
              child: const Text('Try again'),
            ),
          ],
        );
        break;
      default:
        body = const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(padding: const EdgeInsets.all(32), child: body),
      ),
    );
  }
}
