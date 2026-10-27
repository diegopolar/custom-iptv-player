import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/channel.dart';
import 'm3u_parser.dart';

class PlaylistStorage {
  static const _key = 'playlists_v1';

  Future<List<Playlist>> getAll() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getStringList(_key) ?? [];
    return raw
        .map((s) => Playlist.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
  }

  Future<void> _save(List<Playlist> l) async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList(_key, l.map((e) => jsonEncode(e.toJson())).toList());
  }

  Future<void> add(Playlist pl) async => _save([...await getAll(), pl]);

  Future<void> remove(Playlist pl) async {
    final l = await getAll()
      ..removeWhere((e) => e.id == pl.id);
    await _save(l);
    if (pl.isLocal) {
      final f = File(pl.source);
      if (await f.exists()) await f.delete();
    }
  }

  Future<List<Channel>> loadChannels(Playlist pl) async {
    final Uint8List bytes;
    if (pl.isLocal) {
      bytes = await File(pl.source).readAsBytes();
    } else {
      final res = await http
          .get(Uri.parse(pl.source))
          .timeout(const Duration(seconds: 45));
      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}');
      }
      bytes = res.bodyBytes;
    }
    final text = utf8.decode(bytes, allowMalformed: true);
    return compute(parseM3u, text); // parseo en isolate: UI fluida
  }
}
