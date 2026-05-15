import 'package:just_audio/just_audio.dart';

enum SharedAudioOwner { none, quran, library }

class SharedAudioPlayer {
  SharedAudioPlayer._();

  static final SharedAudioPlayer instance = SharedAudioPlayer._();

  final AudioPlayer player = AudioPlayer();
  SharedAudioOwner _owner = SharedAudioOwner.none;

  SharedAudioOwner get owner => _owner;

  Future<void> claim(SharedAudioOwner owner) async {
    if (_owner == owner) {
      return;
    }

    await player.stop();
    _owner = owner;
  }

  Future<void> release(SharedAudioOwner owner) async {
    if (_owner != owner) {
      return;
    }

    await player.stop();
    _owner = SharedAudioOwner.none;
  }
}
