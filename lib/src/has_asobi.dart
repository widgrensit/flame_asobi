import 'package:asobi/asobi.dart';
import 'package:flame/game.dart';

/// Mixin that provides an [AsobiClient] to a [FlameGame].
///
/// Handles client lifecycle — call [asobiConnect] to initialize
/// and the client is automatically disposed when the game is removed.
///
/// Children can access the client via `HasGameRef` and `game.asobi`.
mixin HasAsobi on FlameGame {
  late final AsobiClient asobi;

  /// Initialize and connect to the Asobi backend.
  Future<void> asobiConnect(String host, {int port = 8080, bool useSsl = false}) async {
    asobi = AsobiClient(host, port: port, useSsl: useSsl);
  }

  @override
  void onRemove() {
    asobi.dispose();
    super.onRemove();
  }
}
