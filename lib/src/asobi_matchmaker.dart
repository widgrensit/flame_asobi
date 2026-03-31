import 'dart:async';
import 'package:asobi/asobi.dart';
import 'package:flame/components.dart';

mixin HasAsobiMatchmaker on Component {
  AsobiClient get matchmakerClient;

  String get matchmakerMode => 'default';

  bool _connected = false;
  bool _searching = false;
  double _searchTime = 0;

  StreamSubscription<void>? _connectedSub;
  StreamSubscription<MatchmakerMatch>? _matchedSub;
  StreamSubscription<RealtimeError>? _errorSub;

  bool get isConnected => _connected;

  bool get isSearching => _searching;

  double get searchTime => _searchTime;

  void onMatchmakerConnected() {}

  void onMatchmakerMatched(MatchmakerMatch match) {}

  void onMatchmakerError(RealtimeError error) {}

  Future<void> connectMatchmaker() async {
    _connectedSub = matchmakerClient.realtime.onConnected.stream.listen((_) {
      _connected = true;
      onMatchmakerConnected();
    });
    _matchedSub = matchmakerClient.realtime.onMatchmakerMatched.stream.listen((match) {
      _searching = false;
      onMatchmakerMatched(match);
    });
    _errorSub = matchmakerClient.realtime.onError.stream.listen((error) {
      _searching = false;
      onMatchmakerError(error);
    });
    await matchmakerClient.realtime.connect();
  }

  void findMatch() {
    _searching = true;
    _searchTime = 0;
    matchmakerClient.realtime.addToMatchmaker(mode: matchmakerMode);
  }

  void cancelSearch() {
    _searching = false;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_searching) _searchTime += dt;
  }

  @override
  void onRemove() {
    _connectedSub?.cancel();
    _matchedSub?.cancel();
    _errorSub?.cancel();
    super.onRemove();
  }
}
