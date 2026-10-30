import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() => runApp(const PokemonViewerApp());

const String pokemonEndpoint = 'https://pokeapi.co/api/v2/pokemon';
const Duration requestTimeout = Duration(seconds: 12);
const String initialPokemon = 'pikachu';

const List<String> examplePokemon = [
  'pikachu',
  'espeon',
  'thispokemondoesnotexist',
];

T _field<T>(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is T) return value;
  throw FormatException('Missing or invalid "$key" in the response.');
}

List<String> _namesOf(
  Map<String, dynamic> json,
  String listKey,
  String itemKey,
) {
  return _field<List<dynamic>>(json, listKey).map((entry) {
    final item = _field<Map<String, dynamic>>(
      entry as Map<String, dynamic>,
      itemKey,
    );
    return _field<String>(item, 'name');
  }).toList();
}

class Pokemon {
  final int id;
  final String name;
  final int? baseExperience;
  final int height;
  final int weight;
  final List<PokemonAbility> abilities;
  final List<String> types;
  final List<String> heldItems;
  final List<String> moves;
  final String? frontDefault;

  const Pokemon({
    required this.id,
    required this.name,
    required this.baseExperience,
    required this.height,
    required this.weight,
    required this.abilities,
    required this.types,
    required this.heldItems,
    required this.moves,
    required this.frontDefault,
  });

  factory Pokemon.fromJson(Map<String, dynamic> json) {
    final sprites = _field<Map<String, dynamic>>(json, 'sprites');
    return Pokemon(
      id: _field<int>(json, 'id'),
      name: _field<String>(json, 'name'),
      baseExperience: json['base_experience'] as int?,
      height: _field<int>(json, 'height'),
      weight: _field<int>(json, 'weight'),
      abilities: _field<List<dynamic>>(json, 'abilities')
          .map((item) => PokemonAbility.fromJson(item as Map<String, dynamic>))
          .toList(),
      types: _namesOf(json, 'types', 'type'),
      heldItems: _namesOf(json, 'held_items', 'item'),
      moves: _namesOf(json, 'moves', 'move'),
      frontDefault: sprites['front_default'] as String?,
    );
  }
}

class PokemonAbility {
  final String name;
  final bool isHidden;

  const PokemonAbility({required this.name, required this.isHidden});

  factory PokemonAbility.fromJson(Map<String, dynamic> json) {
    return PokemonAbility(
      name: _field<String>(
        _field<Map<String, dynamic>>(json, 'ability'),
        'name',
      ),
      isHidden: _field<bool>(json, 'is_hidden'),
    );
  }
}

// ---------------------------------------------------------------------------
// Service communication
// ---------------------------------------------------------------------------

enum FailureType { notFound, httpError, network, timeout, invalidData }

class LookupFailure implements Exception {
  final FailureType type;
  final String message;
  final bool canRetry;

  const LookupFailure(this.type, this.message, {this.canRetry = false});
}

Future<Pokemon> fetchPokemon(String name, {http.Client? client}) async {
  final get = client == null ? http.get : client.get;
  final uri = Uri.parse('$pokemonEndpoint/${Uri.encodeComponent(name)}');

  final http.Response response;
  try {
    response = await get(uri).timeout(requestTimeout);
  } on TimeoutException {
    throw const LookupFailure(
      FailureType.timeout,
      'The server took too long to respond.',
      canRetry: true,
    );
  } catch (_) {
    throw const LookupFailure(
      FailureType.network,
      'Could not reach the server. Check your internet connection.',
      canRetry: true,
    );
  }

  if (response.statusCode == 404) {
    throw LookupFailure(
      FailureType.notFound,
      'No Pokémon named "$name" was found. Check the spelling and try again.',
    );
  }
  if (response.statusCode != 200) {
    throw LookupFailure(
      FailureType.httpError,
      'The server returned an unexpected response '
      '(HTTP ${response.statusCode}).',
      canRetry: response.statusCode >= 500,
    );
  }

  try {
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Unexpected response format.');
    }
    return Pokemon.fromJson(decoded);
  } catch (_) {
    throw const LookupFailure(
      FailureType.invalidData,
      'The response could not be processed because the data was not in the '
      'expected format.',
    );
  }
}

// ---------------------------------------------------------------------------
// User interface
// ---------------------------------------------------------------------------

const Map<FailureType, IconData> _failureIcons = {
  FailureType.notFound: Icons.search_off,
  FailureType.httpError: Icons.cloud_off,
  FailureType.network: Icons.wifi_off,
  FailureType.timeout: Icons.timer_off,
  FailureType.invalidData: Icons.report_problem_outlined,
};

const Map<FailureType, String> _failureTitles = {
  FailureType.notFound: 'Pokémon not found',
  FailureType.httpError: 'Server error',
  FailureType.network: 'No connection',
  FailureType.timeout: 'Request timed out',
  FailureType.invalidData: 'Unreadable data',
};

const Map<String, Color> _typeColors = {
  'normal': Color(0xFF8A8A59),
  'fire': Color(0xFFE2692C),
  'water': Color(0xFF4F7FE0),
  'electric': Color(0xFFC99A0B),
  'grass': Color(0xFF4E9E3E),
  'ice': Color(0xFF4FAFAA),
  'fighting': Color(0xFFB02A25),
  'poison': Color(0xFF8E3A8E),
  'ground': Color(0xFFB08F3E),
  'flying': Color(0xFF7B6DD6),
  'psychic': Color(0xFFE0457B),
  'bug': Color(0xFF8A9A12),
  'rock': Color(0xFF8F7A28),
  'ghost': Color(0xFF5E4780),
  'dragon': Color(0xFF5B24E0),
  'dark': Color(0xFF5A463A),
  'steel': Color(0xFF7F7FA0),
  'fairy': Color(0xFFD0688A),
};

class PokemonViewerApp extends StatelessWidget {
  const PokemonViewerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Pokémon Viewer',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF8E79D6)),
        scaffoldBackgroundColor: const Color(0xFFF6F3FC),
      ),
      home: const PokemonHomePage(),
    );
  }
}

class PokemonHomePage extends StatefulWidget {
  // An HTTP client can be supplied for testing; the app uses the default.
  final http.Client? client;
  const PokemonHomePage({super.key, this.client});

  @override
  State<PokemonHomePage> createState() => _PokemonHomePageState();
}

class _PokemonHomePageState extends State<PokemonHomePage> {
  final TextEditingController _nameField = TextEditingController(
    text: initialPokemon,
  );
  final TextEditingController _moveSearch = TextEditingController();
  String _moveQuery = '';

  String? _inputError;
  String _requestedName = initialPokemon;
  bool _isLoading = false;
  Pokemon? _pokemon;
  LookupFailure? _failure;

  @override
  void initState() {
    super.initState();
    // Load a first Pokémon so the screen is not empty on launch.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _submit();
    });
  }

  @override
  void dispose() {
    _nameField.dispose();
    _moveSearch.dispose();
    super.dispose();
  }

  String _titleCase(String value) => value
      .split('-')
      .map(
        (part) => part.isEmpty
            ? part
            : '${part[0].toUpperCase()}${part.substring(1)}',
      )
      .join(' ');

  // PokéAPI names are lowercase and use hyphens, e.g. "mr-mime".
  String _normalize(String input) =>
      input.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '-');

  // Validates the text field, then starts a lookup.
  void _submit() {
    if (_isLoading) return;
    final name = _normalize(_nameField.text);
    if (name.isEmpty) {
      setState(() => _inputError = 'Please enter a Pokémon name.');
      return;
    }
    _lookup(name);
  }

  Future<void> _lookup(String name) async {
    // Ignore repeated submissions while a request is already in progress.
    if (_isLoading) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _inputError = null;
      _requestedName = name;
      // Clear the previous result so old data is never shown next to a new
      // request or a new error message.
      _pokemon = null;
      _failure = null;
    });

    try {
      final result = await fetchPokemon(name, client: widget.client);
      if (!mounted) return;
      setState(() {
        _pokemon = result;
        _moveSearch.clear();
        _moveQuery = '';
        _isLoading = false;
      });
    } on LookupFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _failure = failure;
        _isLoading = false;
      });
    }
  }

  void _useExample(String name) {
    if (_isLoading) return;
    _nameField.text = name;
    _lookup(name);
  }

  @override
  Widget build(BuildContext context) {
    final pokemon = _pokemon;
    final failure = _failure;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Pokémon Viewer',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: const Color(0xFFF6F3FC),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
        children: [
          _buildSearchCard(),
          const SizedBox(height: 18),
          if (_isLoading)
            _buildLoading()
          else if (failure != null)
            _buildFailure(failure)
          else if (pokemon != null)
            ..._buildPokemon(pokemon)
          else
            _buildPrompt(),
          const SizedBox(height: 14),
          const Text(
            'Data from PokéAPI (pokeapi.co).',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black45, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchCard() {
    return Card(
      elevation: 0,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameField,
              readOnly: _isLoading,
              autocorrect: false,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _submit(),
              onChanged: (_) {
                if (_inputError != null) setState(() => _inputError = null);
              },
              decoration: InputDecoration(
                labelText: 'Pokémon name',
                hintText: 'e.g. pikachu',
                errorText: _inputError,
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                // Disabled while loading, so a second request cannot start.
                onPressed: _isLoading ? null : _submit,
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search),
                label: Text(_isLoading ? 'Searching...' : 'Search'),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  'Try:',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                for (final name in examplePokemon)
                  ActionChip(
                    label: Text(name),
                    onPressed: _isLoading ? null : () => _useExample(name),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Card(
      elevation: 0,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
        child: Column(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Looking up "$_requestedName"...',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrompt() {
    return const Card(
      elevation: 0,
      color: Colors.white,
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.catching_pokemon, size: 56, color: Color(0xFF7661B4)),
            SizedBox(height: 10),
            Text(
              'Enter a Pokémon name above to look it up.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFailure(LookupFailure failure) {
    return Card(
      elevation: 0,
      color: const Color(0xFFFDECEC),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              _failureIcons[failure.type],
              size: 48,
              color: const Color(0xFFB3261E),
            ),
            const SizedBox(height: 10),
            Text(
              _failureTitles[failure.type] ?? 'Something went wrong',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(failure.message, textAlign: TextAlign.center),
            // Retrying only makes sense when the cause may be temporary.
            if (failure.canRetry) ...[
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: () => _lookup(_requestedName),
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _buildPokemon(Pokemon p) {
    final sprite = p.frontDefault;
    final visibleMoves = p.moves
        .where(
          (move) =>
              move.replaceAll('-', ' ').toLowerCase().contains(_moveQuery),
        )
        .toList();

    return [
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFE7DFFF), Color(0xFFF8E8F1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Text(
                '#${p.id.toString().padLeft(3, '0')}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF6B5AA6),
                ),
              ),
            ),
            SizedBox(
              height: 190,
              child: sprite == null
                  ? const Icon(Icons.catching_pokemon, size: 100)
                  : Image.network(
                      sprite,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, progress) =>
                          progress == null
                          ? child
                          : const Center(child: CircularProgressIndicator()),
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.catching_pokemon, size: 100),
                    ),
            ),
            Text(
              _titleCase(p.name),
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 5),
            Wrap(
              spacing: 8,
              alignment: WrapAlignment.center,
              children: p.types
                  .map(
                    (type) => Chip(
                      label: Text(
                        '${type.toUpperCase()} TYPE',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      backgroundColor:
                          _typeColors[type] ?? const Color(0xFF7661B4),
                      side: BorderSide.none,
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      const _SectionHeading(
        title: 'Basic Information',
        icon: Icons.info_outline,
      ),
      const SizedBox(height: 10),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.65,
        children: [
          _InfoCard(
            label: 'Base experience',
            value: p.baseExperience == null ? 'N/A' : '${p.baseExperience} XP',
            icon: Icons.bolt,
          ),
          _InfoCard(
            label: 'Height',
            value: '${(p.height / 10).toStringAsFixed(1)} m',
            icon: Icons.height,
          ),
          _InfoCard(
            label: 'Weight',
            value: '${(p.weight / 10).toStringAsFixed(1)} kg',
            icon: Icons.monitor_weight_outlined,
          ),
          _InfoCard(label: 'Pokédex ID', value: '#${p.id}', icon: Icons.tag),
        ],
      ),
      const SizedBox(height: 22),
      const _SectionHeading(title: 'Abilities', icon: Icons.auto_awesome),
      const SizedBox(height: 10),
      ...p.abilities.map(
        (ability) => Card(
          elevation: 0,
          color: Colors.white,
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFE7DFFF),
              child: Icon(Icons.flash_on, color: Color(0xFF6B5AA6)),
            ),
            title: Text(
              _titleCase(ability.name),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              ability.isHidden ? 'Hidden ability' : 'Regular ability',
            ),
          ),
        ),
      ),
      const SizedBox(height: 22),
      const _SectionHeading(title: 'Held Items', icon: Icons.backpack_outlined),
      const SizedBox(height: 10),
      Card(
        elevation: 0,
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: p.heldItems.isEmpty
              ? const Text(
                  'No held items listed.',
                  style: TextStyle(color: Colors.black54),
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: p.heldItems
                      .map((item) => Chip(label: Text(_titleCase(item))))
                      .toList(),
                ),
        ),
      ),
      const SizedBox(height: 22),
      _SectionHeading(
        title: 'Moves (${p.moves.length})',
        icon: Icons.sports_martial_arts,
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _moveSearch,
        onChanged: (value) =>
            setState(() => _moveQuery = value.trim().toLowerCase()),
        decoration: InputDecoration(
          hintText: 'Filter moves...',
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      const SizedBox(height: 8),
      Card(
        elevation: 0,
        color: Colors.white,
        clipBehavior: Clip.antiAlias,
        child: visibleMoves.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No matching moves.'),
              )
            : Column(
                children: [
                  for (int i = 0; i < visibleMoves.length; i++) ...[
                    ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 15,
                        backgroundColor: const Color(0xFFEDE7F8),
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      title: Text(
                        _titleCase(visibleMoves[i]),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (i < visibleMoves.length - 1)
                      const Divider(height: 1, indent: 16, endIndent: 16),
                  ],
                ],
              ),
      ),
    ];
  }
}

class _SectionHeading extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionHeading({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: const Color(0xFF7661B4)),
      const SizedBox(width: 8),
      Text(
        title,
        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
      ),
    ],
  );
}

class _InfoCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _InfoCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      children: [
        Icon(icon, color: const Color(0xFF7661B4), size: 22),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: Colors.black54),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
