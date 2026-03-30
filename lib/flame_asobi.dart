/// Asobi multiplayer game backend integration for Flame.
///
/// Provides components and mixins for real-time multiplayer,
/// matchmaking, and leaderboards powered by the Asobi backend.
library flame_asobi;

export 'src/has_asobi.dart';
export 'src/asobi_network_sync.dart';
export 'src/asobi_player.dart';
export 'src/asobi_projectile.dart';
export 'src/asobi_matchmaker.dart';
export 'src/asobi_input_sender.dart';
export 'package:asobi/asobi.dart' show AsobiClient;
