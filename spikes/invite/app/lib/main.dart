// Spike 3 demo app. Wires the pure-Dart invite logic to two screens.
// Throwaway. It uses an in-memory fake network, so it shows the offline
// behaviour but proves nothing about a real backend or a real phone.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:invite_spike/invite_spike.dart';

void main() => runApp(const InviteSpikeApp());

/// One fake server, one inviter and one redeemer, all in this process.
class Harness extends ChangeNotifier {
  Harness()
    : network = FakeInviteNetwork(
        treeByInviter: {
          'inviter-1': ['Winyo', 'Manyi', 'Otieno'],
        },
      ) {
    network.registerInviter('inviter-1', 'Achieng');
    inviter = Inviter(id: 'inviter-1', pool: TokenPool('inviter-1'));
    redeemer = Redeemer(id: 'redeemer-1');
  }

  final FakeInviteNetwork network;
  late final Inviter inviter;
  late final Redeemer redeemer;
  Uint8List? lastToken;

  bool get online => network.online;
  set online(bool v) {
    network.online = v;
    notifyListeners();
  }

  void changed() => notifyListeners();
}

class InviteSpikeApp extends StatelessWidget {
  const InviteSpikeApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Invite spike',
    theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
    home: HomePage(harness: Harness()),
  );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.harness});
  final Harness harness;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final h = widget.harness;
    return ListenableBuilder(
      listenable: h,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: const Text('Invite spike'),
          actions: [
            const Text('Signal'),
            Switch(
              key: const Key('signal-switch'),
              value: h.online,
              onChanged: (v) => h.online = v,
            ),
          ],
        ),
        body: _tab == 0 ? CreateInviteScreen(h) : EnterCodeScreen(h),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() => _tab = i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.person_add),
              label: 'Create invite',
            ),
            NavigationDestination(
              icon: Icon(Icons.keyboard),
              label: 'Enter code',
            ),
          ],
        ),
      ),
    );
  }
}

class CreateInviteScreen extends StatefulWidget {
  const CreateInviteScreen(this.h, {super.key});
  final Harness h;

  @override
  State<CreateInviteScreen> createState() => _CreateInviteScreenState();
}

class _CreateInviteScreenState extends State<CreateInviteScreen> {
  static const claim = Claim(
    vouchedPersonId: 'p-akinyi',
    namedRelativeId: 'p-otieno',
    text: 'cousin of Otieno through his father',
  );
  BindResult? _result;

  Future<void> _sync() async {
    await widget.h.inviter.sync(widget.h.network);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.h;
    final result = _result;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          Text('Tokens in pool: ${h.inviter.pool.size}'),
          Text('Bindings waiting to upload: ${h.inviter.outbox.length}'),
          const SizedBox(height: 12),
          Text('Claim: ${claim.text}'),
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('create-invite'),
            onPressed: () {
              setState(() {
                final r = h.inviter.bindClaim(claim);
                if (r is BindOk) h.lastToken = r.token;
                _result = r;
              });
            },
            child: const Text('Create invite'),
          ),
          OutlinedButton(
            key: const Key('inviter-sync'),
            onPressed: _sync,
            child: const Text('Sync (needs signal)'),
          ),
          const SizedBox(height: 16),
          if (result is BindOk) ...[
            const Text('Typed code'),
            SelectableText(
              result.formattedCode,
              key: const Key('typed-code'),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            const Text('Link (token only)'),
            SelectableText(result.link, key: const Key('invite-link')),
          ],
          if (result is BindPoolEmpty)
            const Text(BindPoolEmpty.message, key: Key('pool-empty')),
          const SizedBox(height: 24),
          OutlinedButton(
            key: const Key('confirm'),
            onPressed: h.lastToken == null
                ? null
                : () {
                    final out = h.network.confirm(
                      h.lastToken!,
                      byPersonId: 'inviter-1',
                    );
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text(out.name)));
                  },
            child: const Text('Confirm last invite (as inviter)'),
          ),
        ],
      ),
    );
  }
}

class EnterCodeScreen extends StatefulWidget {
  const EnterCodeScreen(this.h, {super.key});
  final Harness h;

  @override
  State<EnterCodeScreen> createState() => _EnterCodeScreenState();
}

class _EnterCodeScreenState extends State<EnterCodeScreen> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final result = widget.h.redeemer.enterCode(_controller.text);
    setState(() {
      _error = result is EntryRejected ? result.message : null;
      if (result is EntrySaved) _controller.clear();
    });
    if (result is EntrySaved) {
      widget.h.redeemer.sync(widget.h.network).then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  Future<void> _sync() async {
    await widget.h.redeemer.sync(widget.h.network);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final screen = widget.h.redeemer.screen;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          TextField(
            key: const Key('code-field'),
            controller: _controller,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: 'Invite code',
              errorText: _error,
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 8),
          FilledButton(
            key: const Key('submit-code'),
            onPressed: _submit,
            child: const Text('Save code'),
          ),
          OutlinedButton(
            key: const Key('redeemer-sync'),
            onPressed: _sync,
            child: const Text('Check for signal'),
          ),
          const SizedBox(height: 16),
          if (screen.message.isNotEmpty)
            Text(screen.message, key: const Key('status')),
          if (screen.inviterName != null)
            Text('Invited by ${screen.inviterName}: ${screen.claimText}'),
          for (final person in screen.tree) Text(person),
        ],
      ),
    );
  }
}
