class Channel {
  final String name;
  final String url;
  final String group;
  final String? logo;
  const Channel({
    required this.name,
    required this.url,
    required this.group,
    this.logo,
  });
}

class Playlist {
  final String id;
  final String name;
  final String source; // URL remota o ruta local
  final bool isLocal;
  const Playlist({
    required this.id,
    required this.name,
    required this.source,
    required this.isLocal,
  });

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'source': source, 'isLocal': isLocal};

  factory Playlist.fromJson(Map<String, dynamic> j) => Playlist(
        id: j['id'] as String,
        name: j['name'] as String,
        source: j['source'] as String,
        isLocal: j['isLocal'] as bool,
      );
}
