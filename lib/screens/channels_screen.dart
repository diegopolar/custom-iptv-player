import 'package:flutter/material.dart';
import '../models/channel.dart';
import '../services/playlist_storage.dart';
import 'player_screen.dart';

class ChannelsScreen extends StatefulWidget {
  final Playlist playlist;
  const ChannelsScreen({super.key, required this.playlist});
  @override
  State<ChannelsScreen> createState() => _ChannelsScreenState();
}

class _ChannelsScreenState extends State<ChannelsScreen> {
  List<Channel>? _all;
  List<String> _groups = [];
  String? _error;
  String _query = '';
  String _group = 'Todos';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _all = null;
      _error = null;
    });
    try {
      final ch = await PlaylistStorage().loadChannels(widget.playlist);
      final groups = ch.map((c) => c.group).toSet().toList()..sort();
      if (!mounted) return;
      setState(() {
        _all = ch;
        _groups = groups;
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'No se pudo cargar la lista:\n$e');
    }
  }

  List<Channel> get _filtered {
    final q = _query.toLowerCase();
    return _all!.where((c) {
      if (_group != 'Todos' && c.group != _group) return false;
      return q.isEmpty || c.name.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.playlist.name)),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: _load, child: const Text('Reintentar')),
          ]),
        ),
      );
    }
    if (_all == null) return const Center(child: CircularProgressIndicator());

    final list = _filtered;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: TextField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Buscar canal…',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
      ),
      SizedBox(
        height: 48,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          children: [
            for (final g in ['Todos', ..._groups])
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: ChoiceChip(
                  label: Text(g),
                  selected: _group == g,
                  onSelected: (_) => setState(() => _group = g),
                ),
              ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text('${list.length} canales',
              style: Theme.of(context).textTheme.bodySmall),
        ),
      ),
      Expanded(
        child: ListView.builder(
          itemCount: list.length,
          itemExtent: 64,
          itemBuilder: (_, i) {
            final c = list[i];
            return ListTile(
              leading: SizedBox(
                width: 48,
                height: 48,
                child: c.logo == null
                    ? const Icon(Icons.tv)
                    : Image.network(
                        c.logo!,
                        fit: BoxFit.contain,
                        cacheWidth: 96,
                        errorBuilder: (_, __, ___) => const Icon(Icons.tv),
                      ),
              ),
              title: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(c.group, maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PlayerScreen(channels: list, index: i),
                ),
              ),
            );
          },
        ),
      ),
    ]);
  }
}
