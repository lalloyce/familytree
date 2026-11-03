/// The simulated network between one device and the fake server. Injects the
/// faults the fuzz needs, all drawn from one seeded Random. Throwaway.
library;

import 'dart:math';

import 'fake_server.dart';
import 'model.dart';

class FaultRates {
  const FaultRates({
    this.midPushDrop = 0.15,
    this.duplicatePush = 0.15,
    this.pullDrop = 0.10,
  });
  static const none = FaultRates(midPushDrop: 0, duplicatePush: 0, pullDrop: 0);

  /// The server stores a prefix of the batch, then the connection drops.
  final double midPushDrop;

  /// The same request reaches the server twice (a retried request whose
  /// first copy also arrived).
  final double duplicatePush;

  /// The server builds a pull page but the response is lost.
  final double pullDrop;
}

class FakeNetwork implements SyncTransport {
  FakeNetwork(this.server, this.rng, {this.faults = const FaultRates()});

  final FakeServer server;
  final Random rng;
  FaultRates faults;
  bool online = false;

  int midPushDrops = 0;
  int duplicatePushes = 0;
  int pullDrops = 0;

  @override
  Future<PushResult> push(List<ClaimRow> rows) async {
    if (!online) throw NetworkError('offline');
    if (rng.nextDouble() < faults.midPushDrop) {
      midPushDrops++;
      final k = rng.nextInt(rows.length + 1);
      server.push(rows.sublist(0, k)); // may itself throw ServerError
      throw NetworkError('connection dropped after $k of ${rows.length}');
    }
    final first = server.push(rows);
    if (rng.nextDouble() < faults.duplicatePush) {
      duplicatePushes++;
      final second = server.push(rows);
      return rng.nextBool() ? first : second;
    }
    return first;
  }

  @override
  Future<PullResult> pull(String? cursor) async {
    if (!online) throw NetworkError('offline');
    final page = server.pull(cursor);
    if (rng.nextDouble() < faults.pullDrop) {
      pullDrops++;
      throw NetworkError('pull response lost');
    }
    return page;
  }
}
