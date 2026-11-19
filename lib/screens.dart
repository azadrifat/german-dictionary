import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import 'data.dart';

// ------------------------------------------------------------- helpers
Color genderColor(String? g) {
  switch (g) {
    case 'masculine':
      return const Color(0xFF8AB4F8);
    case 'feminine':
      return const Color(0xFFF28B9B);
    case 'neuter':
      return const Color(0xFF8FD19E);
    default:
      return Colors.grey;
  }
}

String genderLetter(String? g) {
  switch (g) {
    case 'masculine':
      return 'M';
    case 'feminine':
      return 'F';
    case 'neuter':
      return 'N';
    default:
      return '';
  }
}

String posLabel(String pos) {
  switch (pos) {
    case 'adj':
      return 'ADJECTIVE';
    case 'adv':
      return 'ADVERB';
    case 'intj':
      return 'INTERJECTION';
    case 'pron':
      return 'PRONOUN';
    case 'prep':
      return 'PREPOSITION';
    case 'conj':
      return 'CONJUNCTION';
    default:
      return pos.toUpperCase();
  }
}

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

class GenderBadge extends StatelessWidget {
  const GenderBadge(this.gender, {super.key});
  final String? gender;

  @override
  Widget build(BuildContext context) {
    final letter = genderLetter(gender);
    if (letter.isEmpty) return const SizedBox.shrink();
    return CircleAvatar(
      radius: 13,
      backgroundColor: genderColor(gender),
      child: Text(
        letter,
        style: const TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }
}

class HitTile extends StatelessWidget {
  const HitTile({super.key, required this.hit});
  final Hit hit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      title: Text(
        hit.title,
        style:
            theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        hit.glosses.take(3).join(' · '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontStyle: FontStyle.italic,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(posLabel(hit.pos), style: theme.textTheme.labelSmall),
          const SizedBox(width: 8),
          GenderBadge(hit.gender),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: () => openWord(context, hit.id),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

// ----------------------------------------------------------- app shell
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
      body: SafeArea(
        child: IndexedStack(
          index: _index,
          children: const [SearchPage(), FavoritesPage(), SettingsPage()],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
          NavigationDestination(
              icon: Icon(Icons.star_border), label: 'Favorites'),
          NavigationDestination(
              icon: Icon(Icons.settings_outlined), label: 'Settings'),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------- search
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
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
    final theme = Theme.of(context);
    final empty = _controller.text.trim().isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
          child: Text('Wörterbuch', style: theme.textTheme.headlineMedium),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _controller,
            onChanged: _onChanged,
            textInputAction: TextInputAction.search,
            autocorrect: false,
            decoration: InputDecoration(
              hintText: 'Search word or meaning...',
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
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
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
    );
  }
}

class _HomeLists extends StatelessWidget {
  const _HomeLists();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        return FutureBuilder<List<List<Hit>>>(
          future: Future.wait<List<Hit>>([
            store.hitsFor(store.recents.take(8).toList()),
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
                    'Type a German word (also in a different form, like "ging") '
                    'or an English meaning.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            return ListView(
              children: [
                if (recent.isNotEmpty) const SectionTitle('Recently Visited'),
                for (final h in recent) HitTile(hit: h),
                if (frequent.isNotEmpty)
                  const SectionTitle('Frequently Viewed'),
                for (final h in frequent) HitTile(hit: h),
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
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        return FutureBuilder<List<Hit>>(
          future: store.hitsFor(store.favorites),
          builder: (context, snap) {
            final hits = snap.data;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Text('Favorites',
                      style: Theme.of(context).textTheme.headlineMedium),
                ),
                Expanded(
                  child: hits == null
                      ? const SizedBox.shrink()
                      : hits.isEmpty
                          ? const Center(
                              child: Text(
                                  'Tap the star on a word to save it here.'),
                            )
                          : ListView.builder(
                              itemCount: hits.length,
                              itemBuilder: (_, i) => HitTile(hit: hits[i]),
                            ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// ------------------------------------------------------------ settings
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Settings', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 16),
        const ListTile(
          leading: Icon(Icons.info_outline),
          title: Text('About'),
          subtitle: Text(
            'Offline German-English dictionary. No ads, no tracking.\n'
            'Version 0.1',
          ),
        ),
        const ListTile(
          leading: Icon(Icons.menu_book_outlined),
          title: Text('Data'),
          subtitle: Text(
            'Dictionary data: Wiktionary contributors, extracted by kaikki.org '
            '(licence CC BY-SA 4.0). Audio recordings: Wikimedia Commons.',
          ),
        ),
      ],
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

class _WordView extends StatelessWidget {
  const _WordView({required this.entry, required this.id});
  final Map<String, Object?> entry;
  final int id;

  static const Map<String, String> _classNames = {
    'weak': 'schwach',
    'strong': 'stark',
    'irregular': 'unregelmäßig',
    'mixed': 'gemischt',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final word = entry['word'] as String;
    final pos = (entry['pos'] as String?) ?? '';
    final article = entry['article'] as String?;
    final gender = entry['gender'] as String?;
    final ipa = entry['ipa'] as String?;
    final plural = entry['plural'] as String?;
    final genitive = entry['genitive'] as String?;
    final aux = entry['aux'] as String?;
    final grammar = decodeJson(entry['grammar']);
    final senses = (decodeJson(entry['senses']) as List?) ?? <dynamic>[];
    final forms = decodeJson(entry['forms']);

    final chips = <Widget>[
      Chip(
        label: Text(posLabel(pos).toLowerCase()),
        backgroundColor: theme.colorScheme.tertiaryContainer,
      ),
    ];
    if (pos == 'verb') {
      if (aux != null && aux.isNotEmpty) chips.add(Chip(label: Text(aux)));
      if (grammar is Map) {
        final refl = grammar['reflexive'];
        if (refl == 'yes') chips.add(const Chip(label: Text('sich')));
        if (refl == 'optional')
          chips.add(const Chip(label: Text('sich (opt.)')));
        final cls = grammar['class'];
        if (cls is String)
          chips.add(Chip(label: Text(_classNames[cls] ?? cls)));
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(word),
        actions: [
          ListenableBuilder(
            listenable: store,
            builder: (context, _) => IconButton(
              tooltip: 'Favorite',
              icon: Icon(store.isFavorite(id) ? Icons.star : Icons.star_border),
              onPressed: () => store.toggleFavorite(id),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  article == null ? word : '$article $word',
                  style: theme.textTheme.displaySmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              GenderBadge(gender),
            ],
          ),
          if (ipa != null && ipa.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(ipa, style: theme.textTheme.titleMedium),
            ),
          if (pos == 'noun' && (plural != null || genitive != null))
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                [
                  if (genitive != null) 'Genitiv: $genitive',
                  if (plural != null) 'Plural: $plural',
                ].join('   ·   '),
                style: theme.textTheme.bodyLarge,
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Wrap(spacing: 8, runSpacing: 4, children: chips),
          ),
          const SectionTitleInline('Meanings'),
          for (var i = 0; i < senses.length; i++)
            _SenseView(index: i + 1, sense: senses[i] as Map<String, dynamic>),
          if (forms is Map && pos == 'verb') ...[
            const SectionTitleInline('Conjugation'),
            ConjugationSection(forms: forms.cast<String, dynamic>()),
          ],
          if (forms is Map && pos == 'noun') ...[
            const SectionTitleInline('Declension'),
            DeclensionSection(forms: forms.cast<String, dynamic>()),
          ],
        ],
      ),
    );
  }
}

class SectionTitleInline extends StatelessWidget {
  const SectionTitleInline(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _SenseView extends StatelessWidget {
  const _SenseView({required this.index, required this.sense});
  final int index;
  final Map<String, dynamic> sense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gloss = (sense['g'] as String?) ?? '';
    final tags = ((sense['t'] as List?) ?? <dynamic>[]).cast<String>();
    final examples = ((sense['e'] as List?) ?? <dynamic>[]);
    final syn = ((sense['s'] as List?) ?? <dynamic>[]).cast<String>();
    final ant = ((sense['a'] as List?) ?? <dynamic>[]).cast<String>();

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 30,
                child: Text('$index.',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ),
              Expanded(child: Text(gloss, style: theme.textTheme.titleMedium)),
            ],
          ),
          if (tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 30, top: 6),
              child: Wrap(
                spacing: 6,
                children: [
                  for (final t in tags)
                    Chip(
                      label: Text(t,
                          style: const TextStyle(fontStyle: FontStyle.italic)),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ),
          for (final ex in examples)
            Padding(
              padding: const EdgeInsets.only(left: 30, top: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${(ex as List)[0]}',
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(fontStyle: FontStyle.italic)),
                  Text('${ex[1]}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
          if (syn.isNotEmpty) _RelatedRow(symbol: '≈', words: syn),
          if (ant.isNotEmpty) _RelatedRow(symbol: '≠', words: ant),
        ],
      ),
    );
  }
}

class _RelatedRow extends StatelessWidget {
  const _RelatedRow({required this.symbol, required this.words});
  final String symbol;
  final List<String> words;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 30, top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8, right: 10),
            child: Text(symbol, style: Theme.of(context).textTheme.titleMedium),
          ),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 0,
              children: [
                for (final w in words)
                  ActionChip(
                    label: Text(w),
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
class ConjugationSection extends StatefulWidget {
  const ConjugationSection({super.key, required this.forms});
  final Map<String, dynamic> forms;

  @override
  State<ConjugationSection> createState() => _ConjugationSectionState();
}

class _ConjugationSectionState extends State<ConjugationSection> {
  int _tab = 0;

  Map<String, dynamic> get _tenses =>
      ((widget.forms['tenses'] as Map?) ?? <String, dynamic>{})
          .cast<String, dynamic>();

  String _firstForm(String tense) {
    final rows = _tenses[tense] as List?;
    if (rows == null || rows.isEmpty) return '–';
    final text = '${(rows[0] as List)[1]}';
    return text.split(' / ').first;
  }

  Widget _card(String label, String value) {
    final theme = Theme.of(context);
    return Expanded(
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          child: Column(
            children: [
              Text(label, style: theme.textTheme.labelSmall),
              const SizedBox(height: 4),
              Text(
                value,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tenseTable(String name) {
    final rows = _tenses[name] as List?;
    if (rows == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 4),
          child: Text(
            name.toUpperCase(),
            style: theme.textTheme.labelLarge
                ?.copyWith(color: theme.colorScheme.primary),
          ),
        ),
        for (final r in rows)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: theme.dividerColor),
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 110,
                  child: Text('${(r as List)[0]}',
                      style:
                          TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                ),
                Expanded(
                  child: Text('${r[1]}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _simpleRow(String label, String value) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.forms;
    final infinitive = (f['infinitive'] as String?) ?? '–';
    final partPast = (f['participle_past'] as String?) ?? '–';
    final partPresent = (f['participle_present'] as String?) ?? '–';
    final imperative = ((f['imperative'] as List?) ?? <dynamic>[]).join(', ');

    final List<Widget> content;
    if (_tab == 0) {
      content = [
        for (final n in const [
          'Präsens',
          'Präteritum',
          'Perfekt',
          'Plusquamperfekt',
          'Futur I',
          'Futur II',
        ])
          _tenseTable(n),
      ];
    } else if (_tab == 1) {
      content = [
        for (final n in const ['Konjunktiv I', 'Konjunktiv II']) _tenseTable(n),
      ];
    } else {
      content = [
        const SizedBox(height: 12),
        _simpleRow('Imperativ', imperative.isEmpty ? '–' : imperative),
        _simpleRow('Partizip I', partPresent),
        _simpleRow('Partizip II', partPast),
        _simpleRow('Infinitiv', infinitive),
      ];
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _card('INFINITIV', infinitive),
            _card('PRÄTERITUM', _firstForm('Präteritum')),
            _card('PARTIZIP II', partPast),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment<int>(value: 0, label: Text('Indikativ')),
              ButtonSegment<int>(value: 1, label: Text('Konjunktiv')),
              ButtonSegment<int>(value: 2, label: Text('Weitere')),
            ],
            selected: {_tab},
            onSelectionChanged: (s) => setState(() => _tab = s.first),
          ),
        ),
        ...content,
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
    final header =
        theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary);

    Widget pad(Widget w) =>
        Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: w);

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
            pad(Text(entry.key,
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant))),
            pad(Text(_cell(entry.value, 'singular'),
                style: const TextStyle(fontWeight: FontWeight.bold))),
            pad(Text(_cell(entry.value, 'plural'),
                style: const TextStyle(fontWeight: FontWeight.bold))),
          ]),
      ],
    );
  }
}
