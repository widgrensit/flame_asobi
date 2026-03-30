import 'dart:async';
import 'package:asobi/asobi.dart';
import 'package:flame/components.dart';

/// Component that manages matchmaking lifecycle.
///
/// Connects to the server, queues for a match, and fires callbacks.
///
/// ```dart
/// add(AsobiMatchmaker(
///   client: asobi,
///   mode: 'arena',
///   onConnected: () => print('ready'),
///   onMatched: (payload) => startGame(),
/// ));
/// ```
class AsobiMatchmaker extends Component {
  final AsobiClient client;
  final String mode;
  final void Function()? onConnected;
  final void Function(Map<String, dynamic> payload)? onMatched;
  final void Function(Map<String, dynamic> error)? onError;

  bool _connected = false;
  bool _searching = false;
  double _searchTime = 0;

  StreamSubscription? _connectedSub;
  StreamSubscription? _matchedSub;
  StreamSubscription? _errorSub;

  AsobiMatchmaker({
    required this.client,
    this.mode = 'default',
    this.onConnected,
    this.onMatched,
    this.onError,
  });

  /// Whether the WebSocket is connected and ready.
  bool get isConnected => _connected;

  /// Whether currently searching for a match.
  bool get isSearching => _searching;

  /// Seconds spent searching.
  double get searchTime => _searchTime;

  /// Connect to the server WebSocket.
  Future<void> connect() async {
    _connectedSub = client.realtime.onConnected.stream.listen((_) {
      _connected = true;
      onConnected?.call();
    });
    _matchedSub = client.realtime.onMatchmakerMatched.stream.listen((payload) {
      _searching = false;
      onMatched?.call(payload);
    });
    _errorSub = client.realtime.onError.stream.listen((err) {
      _searching = false;
      onError?.call(err);
    });
    await client.realtime.connect();
  }

  /// Start searching for a match.
  void findMatch() {
    _searching = true;
    _searchTime = 0;
    client.realtime.addToMatchmaker(mode: mode);
  }

  /// Cancel the current search.
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
