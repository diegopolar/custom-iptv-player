import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../models/channel.dart';
import '../services/playlist_storage.dart';
import 'channels_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _store = PlaylistStorage();
  final _urlCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  List<Playlist> _lists = [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final l = await _store.getAll();
    if (mounted) setState(() => _lists = l);
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _addUrl() async {
    final url = _urlCtrl.text.trim();
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || !url.startsWith('http')) {
      _snack('Ingresa una URL válida (http/https)');
      return;
    }
    final name = _nameCtrl.text.trim().isEmpty ? uri.host : _nameCtrl.text.trim();
    await _store.add(Playlist(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      source: url,
      isLocal: false,
    ));
    _urlCtrl.clear();
    _nameCtrl.clear();
    _refresh();
  }

  Future<void> _pickFile() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.any);
    final file = res?.files.single;
    final path = file?.path;
    if (file == null || path == null) return;
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final dir = await getApplicationDocumentsDirectory();
    final dest = await File(path).copy('${dir.path}/$id.m3u');
    await _store.add(Playlist(
      id: id,
      name: file.name,
      source: dest.path,
      isLocal: true,
    ));
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Custom IPTV Player')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _urlCtrl,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'URL de la lista M3U',
              hintText: 'https://iptv-org.github.io/iptv/index.m3u',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Nombre (opcional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _addUrl,
                icon: const Icon(Icons.link),
                label: const Text('Agregar URL'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickFile,
                icon: const Icon(Icons.folder_open),
                label: const Text('Archivo .m3u'),
              ),
            ),
          ]),
          const SizedBox(height: 24),
          Text('Mis listas', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (_lists.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('Aún no has agregado listas')),
            ),
          for (final pl in _lists)
            Card(
              child: ListTile(
                leading: Icon(pl.isLocal ? Icons.insert_drive_file : Icons.cloud),
                title: Text(pl.name),
                subtitle: Text(pl.isLocal ? 'Archivo local' : pl.source,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    await _store.remove(pl);
                    _refresh();
                  },
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ChannelsScreen(playlist: pl)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
