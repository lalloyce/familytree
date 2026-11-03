import 'dart:typed_data';

import 'network.dart';

/// Single-use tokens pre-fetched while online, spent offline.
class TokenPool {
  TokenPool(this.inviterId, {this.batchSize = 20, this.lowWater = 5});

  final String inviterId;
  final int batchSize;

  /// [refillIfLow] fetches when the pool holds this many or fewer.
  final int lowWater;

  final List<Uint8List> _tokens = [];

  int get size => _tokens.length;
  bool get isEmpty => _tokens.isEmpty;

  /// Spends one token, or returns null when the pool is empty. A spent token
  /// is gone for good, so it can never be handed out twice.
  Uint8List? take() => _tokens.isEmpty ? null : _tokens.removeAt(0);

  /// Fetches a batch. Throws [NetworkUnavailable] offline and leaves the pool
  /// as it was.
  Future<int> refill(InviteNetwork network) async {
    final fetched = await network.fetchTokens(inviterId, batchSize);
    _tokens.addAll(fetched);
    return fetched.length;
  }

  /// Refills when low. Returns false, without throwing, when offline.
  Future<bool> refillIfLow(InviteNetwork network) async {
    if (size > lowWater) return true;
    try {
      await refill(network);
      return true;
    } on NetworkUnavailable {
      return false;
    }
  }
}
