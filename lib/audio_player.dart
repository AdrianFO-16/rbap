import 'package:audioplayers/audioplayers.dart';
import 'dart:async';

class AudioPlayerManager {

  // clase encargada de el audio
  final AudioPlayer _audioPlayer = AudioPlayer();
  // callback para notificar a la applicacion cuando un clip termina
  final Function() onClipFinished;
  // estado interno
  bool _isPlaying = false;
  // estado para trackear el source activo (CREO QUE NO LO USAMOS EN REALIDAD)
  late AssetSource currentSource;

  // referencia al timer de fadeout
  Timer? _fadeoutTimer;
  // intervalo de continuidad para el timer
  final Duration _fadeoutInterval = const Duration(milliseconds: 10);

  // Constructor
  AudioPlayerManager({required this.onClipFinished}) {
    // asignamos un callback que llamará al evento de onClipFinished cada vez que el estado del player es completado
    _audioPlayer.onPlayerStateChanged.listen((PlayerState state) {
      if (state == PlayerState.completed) {
        _isPlaying = false;
        onClipFinished();
      }
    });
  }

  // funciones de utilidad para obtener el estado actual del player
  PlayerState getState() => _audioPlayer.state;
  double getVolume() => _audioPlayer.volume;

  // reproducir desde 0 un audio
  Future<void> play(AssetSource? source) async {

    // si reproducimos un audio que no existe entonces queremos parar realmente
    if (source == null){
      stop();
      return;
    }

    // si no lo reproducimos
    currentSource = source;
    await _audioPlayer.play(source);
    _isPlaying = true;
  }

  Future<void> playOrResume(AssetSource? source) async {
    if (source == null){
      stop();
      return;
    }
    if (_audioPlayer.state == PlayerState.playing) {
      return;
    } else if (_audioPlayer.state == PlayerState.completed || _audioPlayer.state == PlayerState.stopped) {
      play(source);
    }
    else
    {
      await _audioPlayer.resume();
    }
  }

  // Method to pause audio
  Future<void> pause() async {
    await _audioPlayer.pause();
    _isPlaying = false;
  }

  // Method to resume audio
  Future<void> resume() async {
    await _audioPlayer.resume();
    _isPlaying = true;
  }

  // Method to stop audio
  Future<void> stop() async {
    await _audioPlayer.stop();
    _isPlaying = false;
  }

  // Method to check if audio is playing
  bool isPlaying() {
    return _isPlaying;
  }

  // Method to set volume
  Future<void> setVolume(double volume) async {
    await _audioPlayer.setVolume(volume);
  }

  // Method to restart audio
  Future<void> restart() async {
    await _audioPlayer.stop();
    await _audioPlayer.seek(Duration.zero);
    await _audioPlayer.resume();
    _isPlaying = true;
  }

  Future<void> setSeek(Duration seek) async {
    await _audioPlayer.seek(seek);
  }


  // funcion para hacer una transicion fadeout, se hace un fadeout de audio y al terminar da play al nuevo clip
  Future<void> fadeOutPlay(Duration duration, AssetSource? source) async {
    if (!_isPlaying) return; // If not playing, no need to fade out

    _fadeoutTimer?.cancel();
    // Calculate the interval for each volume change
    final steps = (duration.inMilliseconds / _fadeoutInterval.inMilliseconds).ceil();
    final deltaVolume = _audioPlayer.volume / steps;

    // Start the fade-out timer
    _fadeoutTimer = Timer.periodic(_fadeoutInterval, (Timer timer) async {
      if (_audioPlayer.volume <= 0) {
        // If volume is already zero, stop the timer and audio
        timer.cancel();
        play(source); // if asset source == null stop
        _audioPlayer.setVolume(1);
        return;
      }

      // Decrease the volume
      final newVolume = (_audioPlayer.volume - deltaVolume).clamp(0.0, 1.0);
      await _audioPlayer.setVolume(newVolume);
    });
  }
}
