import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import 'data.dart';

/// Change this one line to rename the app inside the app.
const String kAppName = 'Wörterbuch';
const String kSerif = 'serif';

// ------------------------------------------------------------- helpers
Color articleColor(BuildContext context, String? gender) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  switch (gender) {
    case 'masculine':
      return dark ? const Color(0xFF8AB4F8) : const Color(0xFF2F6BC2);
    case 'feminine':
      return dark ? const Color(0xFFF28B9B) : const Color(0xFFC2455B);
    case 'neuter':
      return dark ? const Color(0xFF8FD19E) : const Color(0xFF2E8B57);
    default:
      return Theme.of(context).colorScheme.outline;
  }
}

String posLabel(String pos) {
  switch (pos) {
    case 'adj':
      return 'adjective';
    case 'adv':
      return 'adverb';
    case 'intj':
      return 'interjection';
    case 'pron':
      return 'pronoun';
    case 'prep':
      return 'preposition';
    case 'conj':
      return 'conjunction';
    default:
      return pos;
  }
}

List<String> stringList(Object? v) =>
    v is List ? v.map((s) => '$s').toList() : <String>[];

List<List<String>> pairList(Object? v) => v is List
    ? v
        .map((x) => x is List ? x.map((s) => '$s').toList() : <String>['$x'])
        .toList()
    : <List<String>>[];

dynamic decodeJson(Object? v) {
  if (v is String && v.isNotEmpty) {
    try {
      return jsonDecode(v);
    } catch (_) {}
  }
  return null;
}

void openWord(BuildContext context, int id) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => WordPage(id: id)),
  );
}

Future<void> openWordByText(BuildContext context, String word) async {
  final id = await store.findId(word);
  if (!context.mounted) return;
  if (id == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('"$word" is not in the dictionary')),
    );
    return;
  }
  openWord(context, id);
}

/// "der Kauf": the article is coloured by gender, the word is set in a serif face.
class GermanTitle extends StatelessWidget {
  const GermanTitle({
    super.key,
    required this.article,
    required this.word,
    required this.gender,
    this.size = 20,
  });

  final String? article;
  final String word;
  final String? gender;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Text.rich(
      TextSpan(
        children: [
          if (article != null)
            TextSpan(
              text: '$article ',
              style: TextStyle(
                color: articleColor(context, gender),
                fontWeight: FontWeight.w500,
                fontSize: size,
              ),
            ),
          TextSpan(
            text: word,
            style: TextStyle(
              fontFamily: kSerif,
              fontWeight: FontWeight.bold,
              fontSize: size,
              color: scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.top = 28});
  final String text;
  final double top;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(top: top, bottom: 10),
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
          letterSpacing: 1.4,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// A result row: a thin bar in the gender colour, the word, its meanings.
class HitTile extends StatelessWidget {
  const HitTile({super.key, required this.hit});
  final Hit hit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => openWord(context, hit.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 3,
                margin: const EdgeInsets.only(right: 14),
                decoration: BoxDecoration(
                  color: articleColor(context, hit.gender),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GermanTitle(
                      article: hit.article,
                      word: hit.word,
                      gender: hit.gender,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hit.glosses.take(3).join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 4),
                child: Text(
                  posLabel(hit.pos),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- home
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [HomeScreen(), FavoritesPage(), SettingsPage()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
          NavigationDestination(
            icon: Icon(Icons.star_border),
            selectedIcon: Icon(Icons.star),
            label: 'Favorites',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  int _ticket = 0;
  List<Hit> _results = <Hit>[];

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 180), () => _run(text));
  }

  Future<void> _run(String text) async {
    final ticket = ++_ticket;
    if (text.trim().isEmpty) {
      if (mounted) setState(() => _results = <Hit>[]);
      return;
    }
    final hits = await store.search(text);
    if (!mounted || ticket != _ticket) return;
    setState(() => _results = hits);
  }

  @override
  Widget build(BuildContext context) {
    final empty = _controller.text.trim().isEmpty;
    return Scaffold(
      appBar: AppBar(
        title: const Text(kAppName),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _controller,
              onChanged: _onChanged,
              textInputAction: TextInputAction.search,
              autocorrect: false,
              decoration: InputDecoration(
                hintText: 'German or English...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: empty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _controller.clear();
                          _onChanged('');
                        },
                      ),
              ),
            ),
          ),
          Expanded(
            child: empty
                ? const _HomeLists()
                : _results.isEmpty
                    ? const Center(child: Text('No results'))
                    : ListView.builder(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        itemCount: _results.length,
                        itemBuilder: (_, i) => HitTile(hit: _results[i]),
                      ),
          ),
        ],
      ),
    );
  }
}

class _HomeLists extends StatelessWidget {
  const _HomeLists();

  Widget _chips(BuildContext context, List<Hit> hits) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final h in hits)
          ActionChip(
            label: Text(h.title),
            side: BorderSide.none,
            backgroundColor:
                Theme.of(context).colorScheme.surfaceContainerHighest,
            onPressed: () => openWord(context, h.id),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        return FutureBuilder<List<List<Hit>>>(
          future: Future.wait<List<Hit>>([
            store.hitsFor(store.recents.take(12).toList()),
            store.hitsFor(store.frequent),
          ]),
          builder: (context, snap) {
            final data = snap.data;
            if (data == null) return const SizedBox.shrink();
            final recent = data[0];
            final frequent = data[1];
            if (recent.isEmpty && frequent.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'Type a German word (any form, like "ging"), '
                    'or an English meaning.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                if (recent.isNotEmpty) ...[
                  const SectionLabel('Recent', top: 12),
                  _chips(context, recent),
                ],
                if (frequent.isNotEmpty) ...[
                  const SectionLabel('Often'),
                  _chips(context, frequent),
                ],
              ],
            );
          },
        );
      },
    );
  }
}

// ----------------------------------------------------------- favorites
class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Favorites')),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          return FutureBuilder<List<Hit>>(
            future: store.hitsFor(store.favorites),
            builder: (context, snap) {
              final hits = snap.data;
              if (hits == null) return const SizedBox.shrink();
              if (hits.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'Tap the star on a word to keep it here.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              return ListView.builder(
                itemCount: hits.length,
                itemBuilder: (_, i) => HitTile(hit: hits[i]),
              );
            },
          );
        },
      ),
    );
  }
}

// ------------------------------------------------------------ settings
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: const [
          ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('About'),
            subtitle: Text(
              'Offline German-English dictionary. No ads, no tracking.\n'
              'Version 0.3',
            ),
          ),
          ListTile(
            leading: Icon(Icons.menu_book_outlined),
            title: Text('Data'),
            subtitle: Text(
              'Dictionary data: Wiktionary contributors, extracted by '
              'kaikki.org (licence CC BY-SA 4.0). Extra example sentences: '
              'Tatoeba contributors (CC BY 2.0 FR). Audio recordings: '
              'Wikimedia Commons.',
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------- word page
class WordPage extends StatefulWidget {
  const WordPage({super.key, required this.id});
  final int id;

  @override
  State<WordPage> createState() => _WordPageState();
}

class _WordPageState extends State<WordPage> {
  late final Future<Map<String, Object?>?> _entry;

  @override
  void initState() {
    super.initState();
    _entry = store.entry(widget.id);
    WidgetsBinding.instance.addPostFrameCallback((_) => store.visit(widget.id));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, Object?>?>(
      future: _entry,
      builder: (context, snap) {
        final e = snap.data;
        if (e == null) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(
              child: snap.connectionState == ConnectionState.done
                  ? const Text('Entry not found')
                  : const CircularProgressIndicator(),
            ),
          );
        }
        return _WordView(entry: e, id: widget.id);
      },
    );
  }
}

class _WordView extends StatefulWidget {
  const _WordView({required this.entry, required this.id});
  final Map<String, Object?> entry;
  final int id;

  @override
  State<_WordView> createState() => _WordViewState();
}

class _WordViewState extends State<_WordView> {
  final ScrollController _scroll = ScrollController();
  bool _showTitle = false;
  bool _allExpr = false;

  static const Map<String, String> _classNames = {
    'weak': 'schwach',
    'strong': 'stark',
    'irregular': 'unregelmäßig',
    'mixed': 'gemischt',
  };

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final show = _scroll.hasClients && _scroll.offset > 70;
      if (show != _showTitle) setState(() => _showTitle = show);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Widget _strip(BuildContext context, List<List<String>> raw) {
    final theme = Theme.of(context);
    final items = raw.where((i) => i[1].isNotEmpty && i[1] != '–').toList();
    if (items.isEmpty) return const SizedBox.shrink();
    final cells = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      if (i > 0) cells.add(const VerticalDivider(width: 28, thickness: 1));
      cells.add(
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                items[i][0],
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
              const SizedBox(height: 4),
              Text(
                items[i][1],
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: IntrinsicHeight(child: Row(children: cells)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final e = widget.entry;
    final word = e['word'] as String;
    final pos = (e['pos'] as String?) ?? '';
    final article = e['article'] as String?;
    final gender = e['gender'] as String?;
    final ipa = e['ipa'] as String?;
    final plural = e['plural'] as String?;
    final genitive = e['genitive'] as String?;
    final aux = e['aux'] as String?;
    final grammar = decodeJson(e['grammar']);
    final senses = (decodeJson(e['senses']) as List?) ?? <dynamic>[];
    final forms = decodeJson(e['forms']);
    final scheme = theme.colorScheme;
    final extrasRaw = decodeJson(e['extras']);
    final extras = extrasRaw is Map
        ? extrasRaw.cast<String, dynamic>()
        : <String, dynamic>{};
    final expr = pairList(extras['expr']);
    final wordSyn = stringList(extras['syn']);
    final wordAnt = stringList(extras['ant']);
    final family = stringList(extras['fam']);
    final moreExamples = pairList(decodeJson(e['ex_extra']));

    // small grey line above the word: "verb · haben · schwach"
    final caption = <String>[posLabel(pos)];
    if (pos == 'verb') {
      if (aux != null && aux.isNotEmpty) caption.add(aux);
      if (grammar is Map) {
        final cls = grammar['class'];
        if (cls is String) caption.add(_classNames[cls] ?? cls);
        final refl = grammar['reflexive'];
        if (refl == 'yes') caption.add('sich');
        if (refl == 'optional') caption.add('sich (opt.)');
      }
    }

    // the grammar strip under the word
    final List<List<String>> strip = <List<String>>[];
    if (pos == 'noun') {
      strip.add(['Genitiv', genitive ?? '']);
      strip.add(['Plural', plural ?? '']);
    } else if (pos == 'verb' && forms is Map) {
      final tenses = (forms['tenses'] as Map?) ?? <String, dynamic>{};
      var preterite = '';
      final rows = tenses['Präteritum'] as List?;
      if (rows != null && rows.isNotEmpty) {
        preterite = '${(rows[0] as List)[1]}'.split(' / ').first;
      }
      strip.add(['Infinitiv', '${forms['infinitive'] ?? ''}']);
      strip.add(['Präteritum', preterite]);
      strip.add(['Partizip II', '${forms['participle_past'] ?? ''}']);
    }

    return Scaffold(
      appBar: AppBar(
        title: AnimatedOpacity(
          opacity: _showTitle ? 1 : 0,
          duration: const Duration(milliseconds: 150),
          child: GermanTitle(article: article, word: word, gender: gender),
        ),
        actions: [
          ListenableBuilder(
            listenable: store,
            builder: (context, _) => IconButton(
              tooltip: 'Favorite',
              icon: Icon(
                store.isFavorite(widget.id) ? Icons.star : Icons.star_border,
              ),
              onPressed: () => store.toggleFavorite(widget.id),
            ),
          ),
        ],
      ),
      body: ListView(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 48),
        children: [
          Text(
            caption.join('  ·  '),
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.outline,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 6),
          GermanTitle(article: article, word: word, gender: gender, size: 40),
          if (ipa != null && ipa.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                ipa,
                style: theme.textTheme.titleMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          _strip(context, strip),
          const SectionLabel('Meanings'),
          for (var i = 0; i < senses.length; i++)
            _SenseView(index: i + 1, sense: senses[i] as Map<String, dynamic>),
          if (expr.isNotEmpty) ...[
            const SectionLabel('Expressions'),
            for (final x in (_allExpr ? expr : expr.take(5).toList()))
              _ExpressionTile(phrase: x[0], gloss: x.length > 1 ? x[1] : ''),
            if (!_allExpr && expr.length > 5)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => setState(() => _allExpr = true),
                  child: Text('Show all ${expr.length}'),
                ),
              ),
          ],
          if (moreExamples.isNotEmpty) ...[
            const SectionLabel('More examples'),
            for (final x in moreExamples)
              _ExampleBlock(de: x[0], en: x.length > 1 ? x[1] : ''),
          ],
          if (wordSyn.isNotEmpty || wordAnt.isNotEmpty) ...[
            const SectionLabel('Similar and opposite'),
            if (wordSyn.isNotEmpty)
              _RelatedRow(
                icon: Icons.drag_handle,
                tooltip: 'Similar',
                words: wordSyn,
                background: scheme.secondaryContainer,
                foreground: scheme.onSecondaryContainer,
              ),
            if (wordAnt.isNotEmpty)
              _RelatedRow(
                icon: Icons.compare_arrows,
                tooltip: 'Opposite',
                words: wordAnt,
                background: scheme.tertiaryContainer,
                foreground: scheme.onTertiaryContainer,
              ),
          ],
          if (forms is Map && pos == 'verb') ...[
            const SectionLabel('Conjugation'),
            ConjugationChart(forms: forms.cast<String, dynamic>()),
          ],
          if (forms is Map && pos == 'noun') ...[
            const SectionLabel('Declension'),
            DeclensionSection(forms: forms.cast<String, dynamic>()),
          ],
          if (family.isNotEmpty) ...[
            const SectionLabel('Word family'),
            Wrap(
              spacing: 6,
              children: [
                for (final w in family)
                  ActionChip(
                    label: Text(w),
                    backgroundColor: scheme.surfaceContainerHighest,
                    onPressed: () => openWordByText(context, w),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// -------------------------------------------------------------- meanings
class _SenseView extends StatelessWidget {
  const _SenseView({required this.index, required this.sense});
  final int index;
  final Map<String, dynamic> sense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final gloss = (sense['g'] as String?) ?? '';
    final tags = ((sense['t'] as List?) ?? <dynamic>[]).cast<String>();
    final examples = (sense['e'] as List?) ?? <dynamic>[];
    final syn = ((sense['s'] as List?) ?? <dynamic>[]).cast<String>();
    final ant = ((sense['a'] as List?) ?? <dynamic>[]).cast<String>();

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            margin: const EdgeInsets.only(right: 14, top: 1),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.secondaryContainer,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$index',
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.onSecondaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(gloss, style: theme.textTheme.titleMedium),
                if (tags.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      tags.join(' · '),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: scheme.outline,
                      ),
                    ),
                  ),
                for (final ex in examples)
                  _ExampleBlock(de: '${(ex as List)[0]}', en: '${ex[1]}'),
                if (syn.isNotEmpty)
                  _RelatedRow(
                    icon: Icons.drag_handle,
                    tooltip: 'Similar',
                    words: syn,
                    background: scheme.secondaryContainer,
                    foreground: scheme.onSecondaryContainer,
                  ),
                if (ant.isNotEmpty)
                  _RelatedRow(
                    icon: Icons.compare_arrows,
                    tooltip: 'Opposite',
                    words: ant,
                    background: scheme.tertiaryContainer,
                    foreground: scheme.onTertiaryContainer,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExampleBlock extends StatelessWidget {
  const _ExampleBlock({required this.de, required this.en});
  final String de;
  final String en;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.only(left: 12),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: scheme.primary, width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            de,
            style: theme.textTheme.bodyLarge
                ?.copyWith(fontStyle: FontStyle.italic),
          ),
          if (en.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              en,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

class _ExpressionTile extends StatelessWidget {
  const _ExpressionTile({required this.phrase, required this.gloss});
  final String phrase;
  final String gloss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: gloss.isEmpty ? null : () => openWordByText(context, phrase),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              phrase,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            if (gloss.isNotEmpty)
              Text(
                gloss,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
          ],
        ),
      ),
    );
  }
}

class _RelatedRow extends StatelessWidget {
  const _RelatedRow({
    required this.icon,
    required this.tooltip,
    required this.words,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final String tooltip;
  final List<String> words;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Tooltip(
            message: tooltip,
            child: Padding(
              padding: const EdgeInsets.only(top: 8, right: 10),
              child: Icon(icon, size: 20, color: foreground),
            ),
          ),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 0,
              children: [
                for (final w in words)
                  ActionChip(
                    label: Text(w),
                    labelStyle: TextStyle(color: foreground),
                    backgroundColor: background,
                    side: BorderSide.none,
                    visualDensity: VisualDensity.compact,
                    onPressed: () => openWordByText(context, w),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------- conjugation
/// All tenses in one chart: persons down the side, tenses across (swipe sideways).
class ConjugationChart extends StatelessWidget {
  const ConjugationChart({super.key, required this.forms});
  final Map<String, dynamic> forms;

  static const List<String> _persons = [
    'ich',
    'du',
    'er/sie/es',
    'wir',
    'ihr',
    'sie/Sie',
  ];
  static const List<String> _tenseOrder = [
    'Präsens',
    'Präteritum',
    'Perfekt',
    'Plusquamperfekt',
    'Futur I',
    'Futur II',
    'Konjunktiv I',
    'Konjunktiv II',
  ];
  static const double _head = 34;
  static const double _row = 54;
  static const double _colWidth = 170;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tenses = ((forms['tenses'] as Map?) ?? <String, dynamic>{})
        .cast<String, dynamic>();
    final names = _tenseOrder.where(tenses.containsKey).toList();
    final line = BorderSide(color: theme.dividerColor);

    Widget cell(String text, {bool bold = false, double width = _colWidth}) {
      return Container(
        width: width,
        height: _row,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(border: Border(bottom: line)),
        child: Text(
          text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: bold
              ? theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)
              : theme.textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
        ),
      );
    }

    final columns = <Widget>[];
    for (final name in names) {
      final rows = tenses[name] as List;
      columns.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: _head,
              width: _colWidth,
              child: Text(
                name,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            for (var i = 0; i < _persons.length; i++)
              cell(i < rows.length ? '${(rows[i] as List)[1]}' : '–',
                  bold: true),
          ],
        ),
      );
    }

    final imperative =
        ((forms['imperative'] as List?) ?? <dynamic>[]).join(', ');
    final partPresent = (forms['participle_present'] as String?) ?? '';
    final partPast = (forms['participle_past'] as String?) ?? '';

    Widget other(String label, String value) {
      if (value.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: Text(
                label,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                const SizedBox(height: _head, width: 84),
                for (final p in _persons) cell(p, width: 84),
              ],
            ),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: columns,
                ),
              ),
            ),
          ],
        ),
        if (names.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Swipe sideways for more tenses',
              style:
                  theme.textTheme.labelSmall?.copyWith(color: scheme.outline),
            ),
          ),
        if (imperative.isNotEmpty ||
            partPresent.isNotEmpty ||
            partPast.isNotEmpty) ...[
          const SectionLabel('Other forms'),
          other('Imperativ', imperative),
          other('Partizip I', partPresent),
          other('Partizip II', partPast),
        ],
      ],
    );
  }
}

// ----------------------------------------------------------- declension
class DeclensionSection extends StatelessWidget {
  const DeclensionSection({super.key, required this.forms});
  final Map<String, dynamic> forms;

  String _cell(Object? row, String number) {
    if (row is! Map) return '–';
    final list = row[number];
    if (list is List && list.isNotEmpty) return list.join(' / ');
    return '–';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final header = theme.textTheme.labelMedium?.copyWith(
      color: theme.colorScheme.outline,
      letterSpacing: 1,
    );

    Widget pad(Widget w) =>
        Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: w);

    return Table(
      columnWidths: const {0: FixedColumnWidth(96)},
      border: TableBorder(
        horizontalInside: BorderSide(color: theme.dividerColor),
      ),
      children: [
        TableRow(children: [
          pad(const SizedBox.shrink()),
          pad(Text('SINGULAR', style: header)),
          pad(Text('PLURAL', style: header)),
        ]),
        for (final entry in forms.entries)
          TableRow(children: [
            pad(Text(
              entry.key,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            )),
            pad(Text(
              _cell(entry.value, 'singular'),
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            )),
            pad(Text(
              _cell(entry.value, 'plural'),
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            )),
          ]),
      ],
    );
  }
}
