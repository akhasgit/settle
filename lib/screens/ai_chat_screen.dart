import 'dart:developer' as developer;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../ai/settle_agent_service.dart';
import '../ai/settle_agent_factory.dart';
import '../services/expense_service.dart';
import '../services/savings_service.dart';
import '../services/user_service.dart';
import 'conversation_list_screen.dart';

class AIChatScreen extends StatefulWidget {
  final String? initialMessage;
  final String? conversationId;
  /// When true, opens the conversation history sheet as soon as the screen is ready.
  final bool showHistoryOnOpen;

  const AIChatScreen({
    super.key,
    this.initialMessage,
    this.conversationId,
    this.showHistoryOnOpen = false,
  });

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();

  final List<_ChatBubble> _bubbles = [];
  bool _loading = false;
  bool _initialized = false;

  late final String _uid;
  SettleAgentService? _agent;

  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser!.uid;
    _initAgent();
  }

  Future<void> _initAgent() async {
    final userService = UserService();
    final userDoc = await userService.getUserDocument(_uid);
    final userData = userDoc.data() as Map<String, dynamic>? ?? {};

    final name = userData['name'] as String? ?? '';
    final username = userData['username'] as String? ?? '';
    final currency = (userData['defaultCurrency'] as String?) ?? 'SGD';

    final daily = userData['dailyBudget'];
    final weekly = userData['weeklyBudget'];
    final monthly = userData['monthlyBudget'];
    Map<String, double>? budgets;
    if (daily != null || weekly != null || monthly != null) {
      budgets = {};
      if (daily is num) budgets['daily'] = daily.toDouble();
      if (weekly is num) budgets['weekly'] = weekly.toDouble();
      if (monthly is num) budgets['monthly'] = monthly.toDouble();
    }

    final agent = createSettleAgent(
      expenseService: ExpenseService(),
      savingsService: SavingsService(),
      uid: _uid,
      userName: name,
      username: username,
      defaultCurrency: currency,
      budgets: budgets,
    );

    if (widget.conversationId != null) {
      await agent.loadConversation(widget.conversationId!);
      _rebuildBubblesFromHistory(agent);
    } else if (widget.initialMessage != null) {
      await agent.startNewConversation(widget.initialMessage!);
    }

    if (!mounted) return;

    setState(() {
      _agent = agent;
      _initialized = true;
    });

    if (widget.showHistoryOnOpen && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openConversationList();
      });
    }

    if (widget.conversationId == null && widget.initialMessage != null) {
      _sendMessage(widget.initialMessage!);
    }
  }

  void _rebuildBubblesFromHistory(SettleAgentService agent) {
    _bubbles.clear();
    for (final msg in agent.visibleMessages) {
      if (msg.content is String) {
        _bubbles.add(_ChatBubble(role: msg.role, text: msg.content as String));
      }
    }
  }

  Future<void> _sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _loading || _agent == null) return;
    _controller.clear();

    setState(() {
      _bubbles.add(_ChatBubble(role: 'user', text: trimmed));
      _loading = true;
    });
    _scroll();

    try {
      final reply = await _agent!.send(trimmed);
      if (!mounted) return;
      setState(() => _bubbles.add(_ChatBubble(role: 'assistant', text: reply)));
    } catch (e, stackTrace) {
      developer.log('Settle AI send failed', error: e, stackTrace: stackTrace);
      if (!mounted) return;
      final String message;
      if (e is FirebaseFunctionsException) {
        switch (e.code) {
          case 'internal':
            message =
                'Server error. The AI service may be misconfigured — check Firebase Function logs.';
            break;
          case 'unauthenticated':
            message = 'Please sign in again and try again.';
            break;
          default:
            message = e.message ?? 'Sorry, something went wrong. Try again?';
        }
      } else {
        message = 'Sorry, something went wrong. Try again?';
      }
      setState(() => _bubbles.add(_ChatBubble(role: 'assistant', text: message)));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        _scroll();
      }
    }
  }

  void _scroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F5F5),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome, color: Colors.black, size: 20),
            SizedBox(width: 8),
            Text(
              'Settle AI',
              style: TextStyle(
                color: Colors.black,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: Colors.black, size: 22),
            onPressed: _openConversationList,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: !_initialized
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.black))
                : _bubbles.isEmpty && !_loading
                    ? _buildEmptyState()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        itemCount: _bubbles.length + (_loading ? 1 : 0),
                        itemBuilder: (ctx, i) {
                          if (i == _bubbles.length) return _buildTypingIndicator();
                          return _buildBubble(_bubbles[i]);
                        },
                      ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.auto_awesome, size: 30, color: Colors.black),
            ),
            const SizedBox(height: 20),
            const Text(
              'Settle AI',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Ask about your spending, add expenses,\nor get financial advice.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[500], height: 1.5),
            ),
            const SizedBox(height: 28),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _buildSuggestionChip('How much did I spend this week?'),
                _buildSuggestionChip('Add \$5 coffee'),
                _buildSuggestionChip('Compare my spending'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionChip(String text) {
    return GestureDetector(
      onTap: () async {
        if (_agent == null) return;
        if (_agent!.conversationId == null) {
          await _agent!.startNewConversation(text);
        }
        _sendMessage(text);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Text(
          text,
          style: TextStyle(fontSize: 13, color: Colors.grey[700]),
        ),
      ),
    );
  }

  /// Parses text and returns [InlineSpan]s so that segments between ** ** are bold.
  List<InlineSpan> _parseBoldSpans(String text, TextStyle baseStyle) {
    final spans = <InlineSpan>[];
    final parts = text.split('**');
    for (var i = 0; i < parts.length; i++) {
      if (parts[i].isEmpty) continue;
      final isBold = i.isOdd;
      spans.add(TextSpan(
        text: parts[i],
        style: isBold
            ? baseStyle.copyWith(fontWeight: FontWeight.bold)
            : baseStyle,
      ));
    }
    return spans.isEmpty ? [TextSpan(text: text, style: baseStyle)] : spans;
  }

  Widget _buildBubble(_ChatBubble bubble) {
    final isUser = bubble.role == 'user';
    final baseStyle = TextStyle(
      fontSize: 14.5,
      color: isUser ? Colors.white : Colors.black87,
      height: 1.45,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.auto_awesome, size: 14, color: Colors.white),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser ? Colors.black : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
              ),
              child: Text.rich(
                TextSpan(
                  style: baseStyle,
                  children: _parseBoldSpans(bubble.text, baseStyle),
                ),
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 36),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.auto_awesome, size: 14, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const _BouncingDots(),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.of(context).viewPadding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                onSubmitted: (text) {
                  _handleSend();
                  _focusNode.requestFocus();
                },
                textInputAction: TextInputAction.send,
                decoration: InputDecoration(
                  hintText: 'Message Settle AI...',
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 15),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                style: const TextStyle(fontSize: 15),
                maxLines: 4,
                minLines: 1,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _handleSend,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(21),
              ),
              child: Icon(
                Icons.arrow_upward,
                color: _loading ? Colors.grey : Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSend() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _loading || _agent == null) return;

    if (_agent!.conversationId == null) {
      await _agent!.startNewConversation(text);
    }
    _sendMessage(text);
  }

  void _openConversationList() {
    if (_agent == null) return;

    Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => const ConversationListScreen(),
      ),
    ).then((result) async {
      if (result == null || !mounted || _agent == null) return;
      if (result.isEmpty) {
        setState(() {
          _bubbles.clear();
          _agent!.clearHistory();
        });
      } else {
        setState(() {
          _initialized = false;
          _bubbles.clear();
        });
        await _agent!.loadConversation(result);
        if (!mounted) return;
        _rebuildBubblesFromHistory(_agent!);
        setState(() => _initialized = true);
        _scroll();
      }
    });
  }
}

// ─── Chat bubble data ────────────────────────────────────────────────────────

class _ChatBubble {
  final String role;
  final String text;
  const _ChatBubble({required this.role, required this.text});
}

// ─── Typing indicator dots ───────────────────────────────────────────────────

class _BouncingDots extends StatefulWidget {
  const _BouncingDots();

  @override
  State<_BouncingDots> createState() => _BouncingDotsState();
}

class _BouncingDotsState extends State<_BouncingDots>
    with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (i) {
      return AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 400),
      );
    });
    _animations = _controllers.map((c) {
      return Tween<double>(begin: 0, end: -6).animate(
        CurvedAnimation(parent: c, curve: Curves.easeInOut),
      );
    }).toList();

    _startAnimation();
  }

  void _startAnimation() async {
    while (mounted) {
      for (int i = 0; i < 3; i++) {
        if (!mounted) return;
        await Future.delayed(const Duration(milliseconds: 120));
        if (!mounted) return;
        _controllers[i].forward().then((_) {
          if (mounted) _controllers[i].reverse();
        });
      }
      await Future.delayed(const Duration(milliseconds: 400));
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _animations[i],
          builder: (_, __) => Transform.translate(
            offset: Offset(0, _animations[i].value),
            child: Container(
              width: 7,
              height: 7,
              margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
              decoration: BoxDecoration(
                color: Colors.grey[400],
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      }),
    );
  }
}
