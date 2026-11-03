import 'dart:typed_data';

import 'code.dart';
import 'network.dart';
import 'token_pool.dart';

sealed class BindResult {
  const BindResult();
}

/// A claim bound to a token, ready to share.
class BindOk extends BindResult {
  const BindOk({
    required this.code,
    required this.formattedCode,
    required this.link,
    required this.token,
  });

  /// Nine symbols, no separators.
  final String code;

  /// XXXX-XXXX-X for reading aloud or typing.
  final String formattedCode;

  /// Carries only the token, never the relationship.
  final String link;
  final Uint8List token;
}

/// No pre-fetched token is left. The claim was not bound and no token was
/// spent. The caller keeps the claim and offers a retry once online.
class BindPoolEmpty extends BindResult {
  const BindPoolEmpty();
  static const message =
      'No invite codes are ready. Connect to the internet once to get more, '
      'then try again.';
}

/// Placeholder host. `.invalid` is reserved, so it can never resolve.
const defaultLinkBase = 'https://invite.example.invalid';

String inviteLink(String code, {String linkBase = defaultLinkBase}) =>
    '$linkBase/i/${normaliseInviteCode(code)}';

/// Returns the code in a link made by [inviteLink], or null if the link is not
/// one of ours or its code fails the checksum.
String? codeFromInviteLink(String link, {String linkBase = defaultLinkBase}) {
  final prefix = '$linkBase/i/';
  if (!link.startsWith(prefix)) return null;
  final code = link.substring(prefix.length);
  return isValidInviteCode(code) ? normaliseInviteCode(code) : null;
}

class Inviter {
  Inviter({
    required this.id,
    required this.pool,
    this.linkBase = defaultLinkBase,
  });

  final String id;
  final TokenPool pool;
  final String linkBase;

  final List<Binding> _outbox = [];

  /// Bindings made offline, not yet uploaded.
  List<Binding> get outbox => List.unmodifiable(_outbox);

  /// Binds [claim] to a pre-fetched token. Needs no network.
  ///
  /// The token is spent, the binding is queued for upload, and the typed code
  /// and link are derived from the token alone. The claim stays local.
  BindResult bindClaim(Claim claim) {
    final token = pool.take();
    if (token == null) return const BindPoolEmpty();
    _outbox.add(Binding(token: token, claim: claim));
    final code = encodeInviteCode(token);
    return BindOk(
      code: code,
      formattedCode: formatInviteCode(code),
      link: inviteLink(code, linkBase: linkBase),
      token: token,
    );
  }

  /// Uploads queued bindings, then tops up the pool. Offline is not an error:
  /// everything stays queued and false is returned.
  Future<bool> sync(InviteNetwork network) async {
    try {
      if (_outbox.isNotEmpty) {
        await network.uploadBindings(id, List.of(_outbox));
        _outbox.clear();
      }
      await pool.refillIfLow(network);
      return true;
    } on NetworkUnavailable {
      return false;
    }
  }
}
