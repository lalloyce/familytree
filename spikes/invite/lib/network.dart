import 'dart:math';
import 'dart:typed_data';

import 'code.dart';

/// Thrown by every network call while there is no signal.
class NetworkUnavailable implements Exception {
  const NetworkUnavailable();
  @override
  String toString() => 'NetworkUnavailable';
}

/// The relationship an inviter vouches for, e.g. "cousin of X through this
/// parent". It never leaves the inviter's phone except to the server, and is
/// never put in a link or a typed code.
class Claim {
  const Claim({
    required this.vouchedPersonId,
    required this.namedRelativeId,
    required this.text,
  });

  /// The person the inviter vouches for (the invitee's place in the tree).
  final String vouchedPersonId;

  /// The relative the claim names ("cousin of X"). May confirm the invite.
  final String namedRelativeId;

  /// Human-readable claim shown to the redeemer once redemption completes.
  final String text;
}

/// A token bound to a claim on the inviter's phone, waiting to be uploaded.
class Binding {
  const Binding({required this.token, required this.claim});
  final Uint8List token;
  final Claim claim;
}

enum RedeemStatus {
  /// Token known and now held by this redeemer (also returned on a retry).
  accepted,

  /// Token already redeemed by someone else. Tokens are single use.
  alreadyUsed,

  /// Token was never issued.
  unknownToken,
}

class RedeemReceipt {
  const RedeemReceipt(this.status);
  final RedeemStatus status;
}

enum RedeemerStatus {
  /// Redeemer has redeemed nothing.
  none,

  /// Redeemed, but the inviter has not uploaded the binding yet.
  awaitingBinding,

  /// Redeemed and bound. Waiting for the inviter or the named relative.
  awaitingConfirmation,

  /// Confirmed. The tree is visible.
  confirmed,
}

/// What the server shows a redeemer. [tree] is empty until [confirmed].
class RedeemerView {
  const RedeemerView({
    required this.status,
    this.inviterName,
    this.claimText,
    this.tree = const [],
  });
  final RedeemerStatus status;
  final String? inviterName;
  final String? claimText;
  final List<String> tree;
}

enum ConfirmOutcome { confirmed, notAuthorised, nothingToConfirm }

/// The three calls a phone makes. All throw [NetworkUnavailable] offline.
abstract class InviteNetwork {
  Future<List<Uint8List>> fetchTokens(String inviterId, int count);
  Future<void> uploadBindings(String inviterId, List<Binding> bindings);

  /// Idempotent: the same redeemer retrying the same token gets `accepted`.
  Future<RedeemReceipt> redeem(String redeemerId, Uint8List token);
  Future<RedeemerView> fetchView(String redeemerId);
}

/// In-memory server and network switch for tests. Not a real backend.
class FakeInviteNetwork implements InviteNetwork {
  FakeInviteNetwork({Random? random, Map<String, List<String>>? treeByInviter})
    : _random = random ?? Random(1),
      _treeByInviter = treeByInviter ?? {};

  final Random _random;
  final Map<String, List<String>> _treeByInviter;

  /// Flip to simulate airplane mode.
  bool online = true;

  /// Calls that reached the server, for assertions.
  int callsServed = 0;

  final Map<int, String> _issuedTo = {};
  final Map<int, _ServerBinding> _bindings = {};
  final Map<int, String> _redeemedBy = {};
  final Set<int> _confirmed = {};
  final Map<String, String> _inviterNames = {};

  void registerInviter(String inviterId, String name) =>
      _inviterNames[inviterId] = name;

  void _requireOnline() {
    if (!online) throw const NetworkUnavailable();
    callsServed++;
  }

  int _value(Uint8List t) {
    var v = 0;
    for (final b in t) {
      v = (v << 8) | b;
    }
    return v;
  }

  @override
  Future<List<Uint8List>> fetchTokens(String inviterId, int count) async {
    _requireOnline();
    final out = <Uint8List>[];
    while (out.length < count) {
      // Eight random base-31 digits give a canonical token below 31^8.
      var v = 0;
      for (var i = 0; i < inviteTokenSymbols; i++) {
        v = v * 31 + _random.nextInt(31);
      }
      if (_issuedTo.containsKey(v)) continue;
      _issuedTo[v] = inviterId;
      out.add(token5FromValue(v));
    }
    return out;
  }

  @override
  Future<void> uploadBindings(String inviterId, List<Binding> bindings) async {
    _requireOnline();
    for (final b in bindings) {
      final v = _value(b.token);
      if (_issuedTo[v] != inviterId) continue; // not issued to this inviter
      _bindings.putIfAbsent(v, () => _ServerBinding(inviterId, b.claim));
    }
  }

  @override
  Future<RedeemReceipt> redeem(String redeemerId, Uint8List token) async {
    _requireOnline();
    final v = _value(token);
    if (!_issuedTo.containsKey(v)) {
      return const RedeemReceipt(RedeemStatus.unknownToken);
    }
    final holder = _redeemedBy[v];
    if (holder != null && holder != redeemerId) {
      return const RedeemReceipt(RedeemStatus.alreadyUsed);
    }
    _redeemedBy[v] = redeemerId;
    return const RedeemReceipt(RedeemStatus.accepted);
  }

  @override
  Future<RedeemerView> fetchView(String redeemerId) async {
    _requireOnline();
    final entry = _redeemedBy.entries.where((e) => e.value == redeemerId);
    if (entry.isEmpty) {
      return const RedeemerView(status: RedeemerStatus.none);
    }
    final v = entry.first.key;
    final binding = _bindings[v];
    if (binding == null) {
      return const RedeemerView(status: RedeemerStatus.awaitingBinding);
    }
    if (!_confirmed.contains(v)) {
      return RedeemerView(
        status: RedeemerStatus.awaitingConfirmation,
        inviterName: _inviterNames[binding.inviterId],
        claimText: binding.claim.text,
      );
    }
    return RedeemerView(
      status: RedeemerStatus.confirmed,
      inviterName: _inviterNames[binding.inviterId],
      claimText: binding.claim.text,
      tree: List.unmodifiable(_treeByInviter[binding.inviterId] ?? const []),
    );
  }

  /// Server-side confirmation, called when the inviter or the named relative
  /// confirms in their own app. Not part of the redeemer's [InviteNetwork].
  ConfirmOutcome confirm(Uint8List token, {required String byPersonId}) {
    final v = _value(token);
    final binding = _bindings[v];
    if (binding == null || !_redeemedBy.containsKey(v)) {
      return ConfirmOutcome.nothingToConfirm;
    }
    if (byPersonId != binding.inviterId &&
        byPersonId != binding.claim.namedRelativeId) {
      return ConfirmOutcome.notAuthorised;
    }
    _confirmed.add(v);
    return ConfirmOutcome.confirmed;
  }
}

class _ServerBinding {
  _ServerBinding(this.inviterId, this.claim);
  final String inviterId;
  final Claim claim;
}
