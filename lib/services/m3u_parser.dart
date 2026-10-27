import '../models/channel.dart';

final _attrRe = RegExp(r'([\w-]+)="([^"]*)"');

/// Parser M3U. Función de nivel superior para poder usarla con compute().
List<Channel> parseM3u(String content) {
  final out = <Channel>[];
  String? name;
  String? logo;
  String group = 'Sin categoría';

  for (final raw in content.split('\n')) {
    final line = raw.trim();
    if (line.isEmpty) continue;

    if (line.startsWith('#EXTINF')) {
      logo = null;
      group = 'Sin categoría';
      for (final m in _attrRe.allMatches(line)) {
        final key = m.group(1)!.toLowerCase();
        final val = m.group(2)!.trim();
        if (key == 'tvg-logo' && val.isNotEmpty) logo = val;
        if (key == 'group-title' && val.isNotEmpty) group = val;
      }
      final lastQuote = line.lastIndexOf('"');
      final comma = line.indexOf(',', lastQuote < 0 ? 0 : lastQuote);
      name = comma >= 0 ? line.substring(comma + 1).trim() : null;
    } else if (line.startsWith('#EXTGRP:')) {
      group = line.substring(8).trim();
    } else if (!line.startsWith('#')) {
      if (name != null && name.isNotEmpty) {
        out.add(Channel(name: name, url: line, group: group, logo: logo));
      }
      name = null;
    }
  }
  return out;
}
