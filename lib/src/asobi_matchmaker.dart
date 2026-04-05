import 'dart:async';
import 'package:asobi/asobi.dart';
import 'package:flame/components.dart';

/// Mixin that manages the matchmaking lifecycle.
///
/// Mix into your `FlameGame` alongside `HasAsobi` to connect,
/// search for matches, and receive match results via callbacks.
mixin HasAsobiMatchmaker on Component {
  /// The [AsobiClient] used for matchmaking operations.
  AsobiClient get matchmakerClient;

  /// The game mode to search for. Override to change.
  String get matchmakerMode => 'default';

  bool _connected = false;
  bool _searching = false;
  double _searchTime = 0;

  StreamSubscription<void>? _connectedSub;
  StreamSubscription<MatchmakerMatch>? _matchedSub;
  StreamSubscription<RealtimeError>? _errorSub;

  /// Whether the realtime connection is established.
  bool get isConnected => _connected;

  /// Whether a matchmaking search is in progress.
  bool get isSearching => _searching;

  /// Elapsed time in seconds since the current search started.
  double get searchTime => _searchTime;

  /// Called when the realtime connection is established.
  void onMatchmakerConnected() {}

  /// Called when a match is found.
  void onMatchmakerMatched(MatchmakerMatch match) {}

  /// Called when a matchmaking error occurs.
  void onMatchmakerError(RealtimeError error) {}

  /// Connects to the realtime server and begins listening for events.
  Future<void> connectMatchmaker() async {
    _connectedSub = matchmakerClient.realtime.onConnected.stream.listen((_) {
      _connected = true;
      onMatchmakerConnected();
    });
    _matchedSub = matchmakerClient.realtime.onMatchmakerMatched.stream.listen((
      match,
    ) {
      _searching = false;
      onMatchmakerMatched(match);
    });
    _errorSub = matchmakerClient.realtime.onError.stream.listen((error) {
      _searching = false;
      onMatchmakerError(error);
    });
    await matchmakerClient.realtime.connect();
  }

  /// Starts searching for a match using the configured [matchmakerMode].
  void findMatch() {
    _searching = true;
    _searchTime = 0;
    matchmakerClient.realtime.addToMatchmaker(mode: matchmakerMode);
  }

  /// Cancels the current matchmaking search.
  void cancelSearch() {
    _searching = false;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_searching) {
      _searchTime += dt;
    }
  }

  @override
  void onRemove() {
    _connectedSub?.cancel();
    _matchedSub?.cancel();
    _errorSub?.cancel();
    super.onRemove();
  }
}
