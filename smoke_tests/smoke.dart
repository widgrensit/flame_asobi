// Smoke test for flame_asobi against widgrensit/sdk_demo_backend.
//
// Imports only from package:flame_asobi/flame_asobi.dart to verify the
// re-export contract: AsobiClient, AsobiRealtime, etc. must reach users
// of flame_asobi without a separate `package:asobi` dependency.
//
// The Flame mixins (HasAsobi, HasAsobiInput, AsobiNetworkSync, ...) need
// a running FlameGame loop, so they are not exercised here. Proving the
// underlying AsobiClient still works through the bridge package is
// enough to gate releases on the SDK contract.
//
// Expects the backend running at ASOBI_URL (default localhost:8084).
// See widgrensit/sdk_demo_backend/SMOKE.md for the canonical scenarios.

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flame_asobi/flame_asobi.dart';

const _matchMode = 'demo';
const _startupTimeout = Duration(seconds: 60);
const _matchJoinTimeout = Duration(seconds: 10);
const _stateTimeout = Duration(seconds: 3);

Future<void> main() async {
  final url = _parseUrl(
    Platform.environment['ASOBI_URL'] ?? 'http://localhost:8084',
  );

  _log('Waiting for backend at ${url['host']}:${url['port']}');
  await _waitForServer(url);
  _log('Backend reachable.');

  final a = await _spawnPlayer('a', url);
  final b = await _spawnPlayer('b', url);
  _log('Registered: ${a.playerId} | ${b.playerId}');

  // Attach match.matched listeners BEFORE queuing to avoid a race
  // with the server pairing us immediately.
  final matchedA = a.client.realtime.onMatchmakerMatched.stream.first
      .timeout(_matchJoinTimeout);
  final matchedB = b.client.realtime.onMatchmakerMatched.stream.first
      .timeout(_matchJoinTimeout);

  await a.client.realtime.addToMatchmaker(mode: _matchMode);
  await b.client.realtime.addToMatchmaker(mode: _matchMode);
  _log('Both queued.');

  final matchA = await matchedA;
  final matchB = await matchedB;
  _log('Both matched, match_id = ${matchA.matchId}');

  if (matchA.matchId != matchB.matchId) {
    throw Exception(
      'match_id mismatch: ${matchA.matchId} vs ${matchB.matchId}',
    );
  }

  // match.input -> match.state applied.
  // Capture x_initial from the FIRST match.state for the local player,
  // then assert a subsequent state shows x > x_initial + 10. Spawn x is
  // random in [50, 700], so an `x >= 1` check would trivially pass.
  double? xInitial;
  final movedCompleter = Completer<PlayerState>();
  final sub = a.client.realtime.onMatchState.stream.listen((state) {
    final me = state.players[a.playerId];
    if (me == null) {
      return;
    }
    if (xInitial == null) {
      xInitial = me.x + 0.0;
      _log('x_initial = $xInitial');
      a.client.realtime.sendMatchInput({'move_x': 1, 'move_y': 0});
      return;
    }
    if (!movedCompleter.isCompleted && me.x > xInitial! + 10) {
      movedCompleter.complete(me);
    }
  });

  final me = await movedCompleter.future.timeout(_stateTimeout);
  await sub.cancel();
  _log('match.state confirmed: x = ${me.x} (was $xInitial)');

  await a.client.realtime.disconnect();
  await b.client.realtime.disconnect();
  _log('PASS');
  exit(0);
}

// ---- helpers ----

class _Player {
  final AsobiClient client;
  final String playerId;
  _Player(this.client, this.playerId);
}

Future<_Player> _spawnPlayer(String label, Map<String, dynamic> url) async {
  final client = AsobiClient(
    url['host'] as String,
    port: url['port'] as int,
    useSsl: url['useSsl'] as bool,
  );
  final rng = Random();
  final ts = DateTime.now().millisecondsSinceEpoch;
  final username = 'smoke_${label}_${ts}_${rng.nextInt(10000)}';
  final res = await client.auth.register(
    username,
    'smoke_pw_12345',
    displayName: username,
  );
  await client.realtime.connect(autoReconnect: false);
  return _Player(client, res.playerId);
}

Map<String, dynamic> _parseUrl(String url) {
  final uri = Uri.parse(url);
  return {
    'host': uri.host,
    'port': uri.port == 0 ? (uri.scheme == 'https' ? 443 : 80) : uri.port,
    'useSsl': uri.scheme == 'https',
  };
}

Future<void> _waitForServer(Map<String, dynamic> url) async {
  final deadline = DateTime.now().add(_startupTimeout);
  final host = url['host'] as String;
  final port = url['port'] as int;
  final useSsl = url['useSsl'] as bool;
  final scheme = useSsl ? 'https' : 'http';
  final client = HttpClient();
  while (DateTime.now().isBefore(deadline)) {
    try {
      final req = await client.getUrl(
        Uri.parse('$scheme://$host:$port/api/v1/auth/register'),
      );
      final res = await req.close();
      await res.drain();
      if (res.statusCode < 500) {
        client.close();
        return;
      }
    } on Exception catch (_) {
      // connection refused, keep polling
    }
    await Future.delayed(const Duration(seconds: 1));
  }
  client.close();
  throw Exception('backend never became reachable at $scheme://$host:$port');
}

void _log(Object? msg) {
  stderr.writeln('[smoke] $msg');
}
