import 'dart:async';
import 'package:asobi/asobi.dart';
import 'package:flame/components.dart';

/// Component that listens to vote events from the match server.
///
/// Add to your game to react to in-match vote sessions. Set the
/// callback properties to handle each event type, and use [castVote]
/// or [castVeto] to send player choices back to the server.
class AsobiVoteListener extends Component {
  /// The client providing the realtime vote streams.
  final AsobiClient client;

  /// Called when a new vote session starts.
  void Function(Map<String, dynamic> payload)? onVoteStart;

  /// Called when the server broadcasts an interim vote tally.
  void Function(Map<String, dynamic> payload)? onVoteTally;

  /// Called when a vote session concludes with a final result.
  void Function(Map<String, dynamic> payload)? onVoteResult;

  /// Called when a vote is vetoed by a player.
  void Function(Map<String, dynamic> payload)? onVoteVetoed;

  StreamSubscription<Map<String, dynamic>>? _startSub;
  StreamSubscription<Map<String, dynamic>>? _tallySub;
  StreamSubscription<Map<String, dynamic>>? _resultSub;
  StreamSubscription<Map<String, dynamic>>? _vetoedSub;

  /// Creates a vote listener component.
  AsobiVoteListener({
    required this.client,
    this.onVoteStart,
    this.onVoteTally,
    this.onVoteResult,
    this.onVoteVetoed,
  });

  @override
  Future<void> onLoad() async {
    _startSub = client.realtime.onVoteStart.stream.listen(
      (p) => onVoteStart?.call(p),
    );
    _tallySub = client.realtime.onVoteTally.stream.listen(
      (p) => onVoteTally?.call(p),
    );
    _resultSub = client.realtime.onVoteResult.stream.listen(
      (p) => onVoteResult?.call(p),
    );
    _vetoedSub = client.realtime.onVoteVetoed.stream.listen(
      (p) => onVoteVetoed?.call(p),
    );
  }

  /// Casts a vote in an active vote session.
  ///
  /// [optionId] may be a single `String` or a `List<String>` for multi-select.
  void castVote(String voteId, dynamic optionId) {
    client.realtime.castVote(voteId, optionId);
  }

  /// Vetoes an active vote session.
  void castVeto(String voteId) {
    client.realtime.castVeto(voteId);
  }

  @override
  void onRemove() {
    _startSub?.cancel();
    _tallySub?.cancel();
    _resultSub?.cancel();
    _vetoedSub?.cancel();
    super.onRemove();
  }
}
