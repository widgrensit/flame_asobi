import 'dart:async';
import 'package:asobi/asobi.dart';
import 'package:flame/components.dart';

/// Mixin that manages matchmaking lifecycle on any [Component].
///
/// ```dart
/// class MyGame extends FlameGame with HasAsobi, HasAsobiMatchmaker {
///   @override
///   AsobiClient get matchmakerClient => asobi;
///
///   @override
///   String get matchmakerMode => 'arena';
///
///   @override
///   void onMatchmakerConnected() => print('ready');
///
///   @override
///   void onMatchmakerMatched(Map<String, dynamic> payload) => startGame();
/// }
/// ```
mixin HasAsobiMatchmaker on Component {
  /// The Asobi client used for matchmaking.
  AsobiClient get matchmakerClient;

  /// Game mode to search for.
  String get matchmakerMode => 'default';

  bool _mmConnected = false;
  bool _mmSearching = false;
  double _mmSearchTime = 0;

  StreamSubscription? _mmConnectedSub;
  StreamSubscription? _mmMatchedSub;
  StreamSubscription? _mmErrorSub;

  /// Whether the WebSocket is connected and ready.
  bool get isConnected => _mmConnected;

  /// Whether currently searching for a match.
  bool get isSearching => _mmSearching;

  /// Seconds spent searching.
  double get searchTime => _mmSearchTime;

  /// Called when WebSocket connects.
  void onMatchmakerConnected() {}

  /// Called when a match is found.
  void onMatchmakerMatched(Map<String, dynamic> payload) {}

  /// Called on matchmaker error.
  void onMatchmakerError(Map<String, dynamic> error) {}

  /// Connect to the server WebSocket and start listening.
  Future<void> connectMatchmaker() async {
    _mmConnectedSub = matchmakerClient.realtime.onConnected.stream.listen((_) {
      _mmConnected = true;
      onMatchmakerConnected();
    });
    _mmMatchedSub = matchmakerClient.realtime.onMatchmakerMatched.stream.listen((payload) {
      _mmSearching = false;
      onMatchmakerMatched(payload);
    });
    _mmErrorSub = matchmakerClient.realtime.onError.stream.listen((err) {
      _mmSearching = false;
      onMatchmakerError(err);
    });
    await matchmakerClient.realtime.connect();
  }

  /// Start searching for a match.
  void findMatch() {
    _mmSearching = true;
    _mmSearchTime = 0;
    matchmakerClient.realtime.addToMatchmaker(mode: matchmakerMode);
  }

  /// Cancel the current search.
  void cancelSearch() {
    _mmSearching = false;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_mmSearching) _mmSearchTime += dt;
  }

  @override
  void onRemove() {
    _mmConnectedSub?.cancel();
    _mmMatchedSub?.cancel();
    _mmErrorSub?.cancel();
    super.onRemove();
  }
}
