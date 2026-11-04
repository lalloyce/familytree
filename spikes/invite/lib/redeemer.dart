import 'dart:typed_data';

import 'code.dart';
import 'network.dart';

/// The only thing a redeemer sees while offline or before confirmation.
const savedMessage = 'saved, we will connect when you have signal';

const typoMessage = 'That code has a typo. Check it and try again.';
const rejectedMessage = 'This code could not be used.';
const awaitingConfirmationMessage =
    'waiting for the person who invited you to confirm';

sealed class EntryResult {
  const EntryResult();
}

/// Checksum failed at the keyboard. Nothing was stored.
class EntryRejected extends EntryResult {
  const EntryRejected();
  String get message => typoMessage;
}

/// Checksum passed. The code is queued. [message] is the only thing shown.
class EntrySaved extends EntryResult {
  const EntrySaved();
  String get message => savedMessage;
}

enum SavedState { saved, redeemed, rejected }

class SavedCode {
  SavedCode(this.code, this.token);
  final String code;
  final Uint8List token;
  SavedState state = SavedState.saved;
}

/// What the redeemer's screen shows. [tree] is empty until confirmed.
class RedeemerScreen {
  const RedeemerScreen({
    this.message = '',
    this.inviterName,
    this.claimText,
    this.tree = const [],
  });
  final String message;
  final String? inviterName;
  final String? claimText;
  final List<String> tree;
}

class Redeemer {
  Redeemer({required this.id});

  final String id;
  final List<SavedCode> _queue = [];
  RedeemerView? _view;

  List<SavedCode> get queue => List.unmodifiable(_queue);

  /// Validates the checksum with no network. A bad code is refused at once and
  /// stored nowhere. A good code is queued for redemption.
  EntryResult enterCode(String raw) {
    final token = decodeInviteCode(raw);
    if (token == null) return const EntryRejected();
    final code = normaliseInviteCode(raw);
    if (!_queue.any((s) => s.code == code)) {
      _queue.add(SavedCode(code, token));
    }
    return const EntrySaved();
  }

  /// Redeems queued codes and refreshes the view. When signal is missing,
  /// everything stays queued and false is returned.
  Future<bool> sync(InviteNetwork network) async {
    try {
      for (final saved
          in _queue.where((s) => s.state == SavedState.saved).toList()) {
        final receipt = await network.redeem(id, saved.token);
        saved.state = receipt.status == RedeemStatus.accepted
            ? SavedState.redeemed
            : SavedState.rejected;
      }
      if (_queue.any((s) => s.state == SavedState.redeemed)) {
        _view = await network.fetchView(id);
      }
      return true;
    } on NetworkUnavailable {
      return false;
    }
  }

  /// Everything the redeemer can see right now.
  RedeemerScreen get screen {
    final view = _view;
    if (view != null && view.status == RedeemerStatus.confirmed) {
      return RedeemerScreen(
        inviterName: view.inviterName,
        claimText: view.claimText,
        tree: view.tree,
      );
    }
    if (view != null && view.status == RedeemerStatus.awaitingConfirmation) {
      return RedeemerScreen(
        message: awaitingConfirmationMessage,
        inviterName: view.inviterName,
        claimText: view.claimText,
      );
    }
    if (_queue.any((s) => s.state != SavedState.rejected)) {
      return const RedeemerScreen(message: savedMessage);
    }
    if (_queue.isNotEmpty) {
      return const RedeemerScreen(message: rejectedMessage);
    }
    return const RedeemerScreen();
  }
}
