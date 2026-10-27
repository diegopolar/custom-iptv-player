import 'dart:async';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../models/channel.dart';

class PlayerScreen extends StatefulWidget {
  final List<Channel> channels;
  final int index;
  const PlayerScreen({super.key, required this.channels, required this.index});
  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  static const _hideDelay = Duration(seconds: 4);

  late int _index;
  VideoPlayerController? _vc;
  ChewieController? _cc;
  Timer? _hideTimer;
  bool _controlsVisible = true;
  bool _failed = false;
  int _gen = 0; // evita condiciones de carrera al zapear rápido
  final _focus = FocusNode();

  Channel get _channel => widget.channels[_index];

  @override
  void initState() {
    super.initState();
    _index = widget.index;
    SystemChrome.setPreferredOrientations(
        [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _open();
    _scheduleHide();
  }

  @override
  void dispose() {
    _gen++;
    _hideTimer?.cancel();
    _focus.dispose();
    _cc?.dispose();
    _vc?.dispose();
    SystemChrome.setPreferredOrientations([]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _open() async {
    final gen = ++_gen;
    final oldCc = _cc, oldVc = _vc;
    setState(() {
      _cc = null;
      _vc = null;
    });
    oldCc?.dispose();
    await oldVc?.dispose();

    final vc = VideoPlayerController.networkUrl(
      Uri.parse(_channel.url),
      // ExoPlayer usa MediaCodec (decodificación por hardware) por defecto
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
    );
    try {
      await vc.initialize().timeout(const Duration(seconds: 20));
      if (!mounted || gen != _gen) {
        await vc.dispose();
        return;
      }
      vc.addListener(() {
        if (gen == _gen && vc.value.hasError) _fail();
      });
      final cc = ChewieController(
        videoPlayerController: vc,
        autoPlay: true,
        isLive: true,
        showControls: false, // controles propios con auto-ocultado
        allowFullScreen: false,
        aspectRatio: vc.value.aspectRatio > 0 ? vc.value.aspectRatio : 16 / 9,
      );
      setState(() {
        _vc = vc;
        _cc = cc;
      });
    } catch (_) {
      await vc.dispose();
      if (gen == _gen) _fail();
    }
  }

  void _fail() {
    if (_failed || !mounted) return;
    _failed = true;
    final messenger = ScaffoldMessenger.of(context);
    final name = _channel.name;
    Navigator.of(context).pop();
    messenger.showSnackBar(SnackBar(
      content: Text('No se pudo reproducir "$name". Stream caído o sin conexión.'),
    ));
  }

  void _go(int delta) {
    final n = widget.channels.length;
    setState(() => _index = (_index + delta + n) % n);
    _open();
    _showControls();
  }

  void _showControls() {
    setState(() => _controlsVisible = true);
    _scheduleHide();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(_hideDelay, () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  void _toggle() {
    if (_controlsVisible) {
      _hideTimer?.cancel();
      setState(() => _controlsVisible = false);
    } else {
      _showControls();
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.arrowLeft ||
        k == LogicalKeyboardKey.arrowDown ||
        k == LogicalKeyboardKey.channelDown ||
        k == LogicalKeyboardKey.mediaTrackPrevious) {
      _go(-1);
    } else if (k == LogicalKeyboardKey.arrowRight ||
        k == LogicalKeyboardKey.arrowUp ||
        k == LogicalKeyboardKey.channelUp ||
        k == LogicalKeyboardKey.mediaTrackNext) {
      _go(1);
    } else if (k == LogicalKeyboardKey.select || k == LogicalKeyboardKey.enter) {
      _toggle();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggle,
          child: Stack(fit: StackFit.expand, children: [
            Center(
              child: _cc == null
                  ? const CircularProgressIndicator()
                  : Chewie(controller: _cc!),
            ),
            AnimatedOpacity(
              opacity: _controlsVisible ? 1 : 0,
              duration: const Duration(milliseconds: 250),
              child: IgnorePointer(
                ignoring: !_controlsVisible,
                child: _overlay(),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _overlay() {
    return Stack(children: [
      Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.center,
            colors: [Colors.black87, Colors.transparent],
          ),
        ),
        padding: const EdgeInsets.fromLTRB(8, 8, 16, 24),
        child: Align(
          alignment: Alignment.topLeft,
          child: Row(children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_channel.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  Text(_channel.group,
                      style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.circle, color: Colors.red, size: 10),
            const SizedBox(width: 4),
            const Text('EN VIVO',
                style: TextStyle(color: Colors.white, fontSize: 12)),
          ]),
        ),
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: _navButton(Icons.skip_previous, 'Canal anterior', () => _go(-1)),
      ),
      Align(
        alignment: Alignment.centerRight,
        child: _navButton(Icons.skip_next, 'Canal siguiente', () => _go(1)),
      ),
    ]);
  }

  Widget _navButton(IconData icon, String tip, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: IconButton.filledTonal(
        tooltip: tip,
        iconSize: 40,
        icon: Icon(icon),
        onPressed: onTap,
      ),
    );
  }
}
