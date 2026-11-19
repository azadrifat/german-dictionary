import 'package:flutter/material.dart';

import 'data.dart';
import 'screens.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DictApp());
}

class DictApp extends StatelessWidget {
  const DictApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF2F7DD1);
    return MaterialApp(
      title: 'Wörterbuch',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: seed,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: seed,
        brightness: Brightness.dark,
      ),
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
    if (_state == 'ready') return const HomeShell();

    final theme = Theme.of(context);
    Widget body;
    switch (_state) {
      case 'needs':
        body = Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.menu_book_outlined, size: 72),
            const SizedBox(height: 16),
            Text('Wörterbuch', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 16),
            const Text(
              'The dictionary data has to be downloaded once '
              '(about 30 MB, it takes about 110 MB on your phone). '
              'Please use Wi-Fi.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _download,
              icon: const Icon(Icons.download),
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
            LinearProgressIndicator(value: _progress),
            const SizedBox(height: 12),
            Text(_message),
          ],
        );
        break;
      case 'error':
        body = Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 56),
            const SizedBox(height: 16),
            Text('Something went wrong', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            Text(_error, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton(onPressed: _start, child: const Text('Try again')),
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
