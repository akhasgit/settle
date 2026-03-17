import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/bank_service.dart';

/// Launches the Finverse Link flow inside a WebView so the user can securely
/// connect their DBS/POSB account. On success, saves the connection ID to
/// Firestore and pops back to Settings.
class BankConnectionScreen extends StatefulWidget {
  const BankConnectionScreen({super.key});

  @override
  State<BankConnectionScreen> createState() => _BankConnectionScreenState();
}

class _BankConnectionScreenState extends State<BankConnectionScreen> {
  static const String _redirectScheme = 'settle';
  static const String _redirectHost = 'bank-connected';

  WebViewController? _webController;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initLink();
  }

  Future<void> _initLink() async {
    try {
      // Ask the Cloud Function for a short-lived Finverse link token
      final callable = FirebaseFunctions.instance.httpsCallable('createFinverseLink');
      final result = await callable.call();
      final linkToken = result.data['linkToken'] as String;

      // Build the Finverse Link URL; redirect URI uses a custom scheme so the
      // WebView can intercept it without needing a registered HTTPS domain.
      final linkUrl =
          'https://link.finverse.net?link_token=$linkToken'
          '&redirect_uri=$_redirectScheme://$_redirectHost';

      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onNavigationRequest: (request) {
              final uri = Uri.tryParse(request.url);
              if (uri != null &&
                  uri.scheme == _redirectScheme &&
                  uri.host == _redirectHost) {
                _handleCallback(uri);
                return NavigationDecision.prevent;
              }
              return NavigationDecision.navigate;
            },
          ),
        )
        ..loadRequest(Uri.parse(linkUrl));

      if (mounted) {
        setState(() {
          _webController = controller;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Could not start bank connection. Please try again.';
          _loading = false;
        });
      }
    }
  }

  /// Called when Finverse redirects back to settle://bank-connected?connection_id=...
  Future<void> _handleCallback(Uri uri) async {
    final connectionId = uri.queryParameters['connection_id'];
    final institution = uri.queryParameters['institution'] ?? 'DBS';

    if (connectionId == null || connectionId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bank connection failed. Please try again.')),
        );
        Navigator.of(context).pop();
      }
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      await BankService().saveConnection(
        uid: uid,
        connectionId: connectionId,
        institutionName: institution,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$institution account connected!'),
            backgroundColor: Colors.black,
          ),
        );
        Navigator.of(context).pop(true); // true = connection saved
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save connection. Please try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Connect Bank Account',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.black),
            SizedBox(height: 16),
            Text(
              'Preparing secure connection...',
              style: TextStyle(color: Color(0xFF757575)),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF757575)),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _loading = true;
                    _error = null;
                  });
                  _initLink();
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
                child: const Text('Retry', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    return WebViewWidget(controller: _webController!);
  }
}
