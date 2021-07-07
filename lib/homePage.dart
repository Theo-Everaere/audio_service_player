import 'package:audio_service/audio_service.dart';
import 'package:background_music/database.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

MediaItem mediaItem = MediaItem(
  id: songList[0].url,
  title: songList[0].name,
  artUri: Uri.parse(songList[0].icon),
  album: songList[0].album,
  duration: songList[0].duration,
  artist: songList[0].artist,
);

int current = 0;

_backgroundTaskEntrypoint() {
  AudioServiceBackground.run(() => AudioPlayerTask());
}

class AudioPlayerTask extends BackgroundAudioTask {
  final _audioPlayer = AudioPlayer();
  List<MediaControl> setControls = [
    MediaControl.skipToPrevious,
    MediaControl.stop,
    MediaControl.play,
    MediaControl.pause,
    MediaControl.skipToNext,
  ];

  @override
  Future<void> onStart(Map<String, dynamic> params) async {
    AudioServiceBackground.setState(
      // Définit l'état de lecture actuel et dicte quelles actions multimédias peuvent être contrôlées par les clients et quelles commandes et actions multimédias doivent être activées dans la notification.
      //  Chaque contrôle répertorié dans [controls] apparaîtra sous la forme d'un bouton dans la notification et son action sera également disponible pour tous les clients
      controls: setControls,
      systemActions: [
        MediaAction.seekTo
      ], // Toutes les actions supplémentaires que vous souhaitez activer pour les clients qui ne correspondent pas à un bouton peuvent être répertoriées dans systemActions.
      playing: true,
      processingState: AudioProcessingState.connecting,
    );
    // Connect to the URL
    await _audioPlayer.setUrl(mediaItem.id);
    AudioServiceBackground.setMediaItem(mediaItem);
    // Now we're ready to play
    _audioPlayer.play();
    // Broadcast that we're playing, and what controls are available.
    AudioServiceBackground.setState(
      controls: setControls,
      systemActions: [MediaAction.seekTo],
      playing: true,
      processingState: AudioProcessingState.ready,
    );
  }

  @override
  Future<void> onPlay() async {
    AudioServiceBackground.setState(
      controls: setControls,
      systemActions: [MediaAction.seekTo],
      playing: true,
      processingState: AudioProcessingState.ready,
    );
    await _audioPlayer.play();
    return super.onPlay();
  }

  @override
  Future<void> onStop() async {
    AudioServiceBackground.setState(
        controls: [],
        playing: false,
        processingState: AudioProcessingState.ready);
    await _audioPlayer.stop();
    await super.onStop();
  }

  @override
  Future<void> onPause() async {
    AudioServiceBackground.setState(
      controls: setControls,
      systemActions: [MediaAction.seekTo],
      playing: false,
      processingState: AudioProcessingState.ready,
    );
    await _audioPlayer.pause();
    return super.onPause();
  }

  @override
  Future<void> onSkipToNext() async {
    if (current < songList.length - 1)
      current = current + 1;
    else
      current = 0;
    mediaItem = MediaItem(
        id: songList[current].url,
        title: songList[current].name,
        artUri: Uri.parse(songList[current].icon),
        album: songList[current].album,
        duration: songList[current].duration,
        artist: songList[current].artist);
    AudioServiceBackground.setMediaItem(mediaItem);
    await _audioPlayer.setUrl(mediaItem.id);
    AudioServiceBackground.setState(position: Duration.zero);
    return super.onSkipToNext();
  }

  @override
  Future<void> onSkipToPrevious() async {
    if (current != 0)
      current = current - 1;
    else
      current = songList.length - 1;
    mediaItem = MediaItem(
      id: songList[current].url,
      title: songList[current].name,
      artUri: Uri.parse(songList[current].icon),
      album: songList[current].album,
      duration: songList[current].duration,
      artist: songList[current].artist,
    );
    AudioServiceBackground.setMediaItem(mediaItem);
    await _audioPlayer.setUrl(mediaItem.id);
    AudioServiceBackground.setState(position: Duration.zero);
    return super.onSkipToPrevious();
  }

  @override
  Future<void> onSeekTo(Duration position) {
    _audioPlayer.seek(position);
    AudioServiceBackground.setState(position: position);
    return super.onSeekTo(position);
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.grey,
        body: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            StreamBuilder<MediaItem>(
                stream: AudioService.currentMediaItemStream,
                builder: (_, snapshot) {
                  return Text(
                    snapshot.data?.title ?? "Title",
                    style: TextStyle(fontSize: 25, color: Colors.white),
                  );
                }),
            // The playback state for the audio service which includes a [playing] boolean state, a processing state such as [AudioProcessingState.buffering], the playback position and the currently enabled actions to be shown in the Android notification or the iOS control center.
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () async {
                    await AudioService.skipToPrevious();
                  },
                  icon: Icon(
                    Icons.skip_previous,
                    size: 40,
                  ),
                ),
                IconButton(
                  onPressed: () async {
                    await AudioService.stop();
                  },
                  icon: Icon(
                    Icons.stop,
                    size: 40,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    // [.start] Starts a background audio task which will continue running even when the UI is not visible or the screen is turned off.
                    AudioService.start(
                      backgroundTaskEntrypoint: _backgroundTaskEntrypoint,
                    );
                    AudioService.play();
                  },
                  icon: Icon(
                    Icons.play_arrow_sharp,
                    size: 40,
                  ),
                ),
                IconButton(
                  onPressed: () async {
                    await AudioService.pause();
                  },
                  icon: Icon(
                    Icons.pause,
                    size: 40,
                  ),
                ),
                IconButton(
                  onPressed: () async {
                    await AudioService.skipToNext();
                  },
                  icon: Icon(
                    Icons.skip_next,
                    size: 40,
                  ),
                ),
              ],
            ),
            StreamBuilder<Duration>(
              stream: AudioService.positionStream,
              builder: (_, snapshot) {
                final mediaState = snapshot.data;
                return Slider(
                  value: mediaState?.inSeconds?.toDouble() ?? 0,
                  min: 0,
                  max: mediaItem.duration.inSeconds.toDouble(),
                  onChanged: (val) {
                    AudioService.seekTo(Duration(seconds: val.toInt()));
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
