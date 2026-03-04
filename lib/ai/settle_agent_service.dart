import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'settle_tools.dart';
import 'settle_prompt.dart';

class AgentMessage {
  final String role;
  final dynamic content;

  const AgentMessage({required this.role, required this.content});

  Map<String, dynamic> toJson() => {'role': role, 'content': content};

  factory AgentMessage.fromJson(Map<String, dynamic> json) {
    return AgentMessage(role: json['role'] as String, content: json['content']);
  }
}

class SettleAgentService {
  final _fn = FirebaseFunctions.instance.httpsCallable(
    'claudeProxy',
    options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
  );
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<AgentMessage> _history = [];
  String? _conversationId;
  final String _uid;

  final Future<void> Function(Map<String, dynamic>) onAddExpense;
  final Future<void> Function(String goalName, double amount, String currency)
      onAddSavings;
  final Future<Map<String, dynamic>> Function(String period,
      {String? start, String? end, String? groupBy}) onGetSummary;

  final String userName;
  final String username;
  final String defaultCurrency;
  final Map<String, double>? budgets;

  SettleAgentService({
    required String uid,
    required this.onAddExpense,
    required this.onAddSavings,
    required this.onGetSummary,
    required this.userName,
    required this.username,
    required this.defaultCurrency,
    this.budgets,
  }) : _uid = uid;

  String? get conversationId => _conversationId;

  CollectionReference get _conversationsRef =>
      _firestore.collection('users').doc(_uid).collection('conversations');

  /// Start a brand-new conversation and persist the initial doc
  Future<String> startNewConversation(String firstUserMessage) async {
    _history.clear();
    final docRef = _conversationsRef.doc();
    _conversationId = docRef.id;

    final title = firstUserMessage.length > 60
        ? '${firstUserMessage.substring(0, 60)}...'
        : firstUserMessage;

    await docRef.set({
      'title': title,
      'preview': '',
      'messages': [],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return _conversationId!;
  }

  /// Load an existing conversation's history from Firestore
  Future<void> loadConversation(String conversationId) async {
    _conversationId = conversationId;
    final doc = await _conversationsRef.doc(conversationId).get();
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final rawMessages = data['messages'] as List<dynamic>? ?? [];

    _history = rawMessages.map((m) {
      final map = Map<String, dynamic>.from(m as Map);
      return AgentMessage.fromJson(map);
    }).toList();
  }

  /// Send a user message, run the agentic loop, persist, and return the reply
  Future<String> send(String userMessage) async {
    _history.add(AgentMessage(role: 'user', content: userMessage));

    final systemPrompt = buildSystemPrompt(
      userName: userName,
      username: username,
      today: DateTime.now().toIso8601String().split('T').first,
      defaultCurrency: defaultCurrency,
      budgets: budgets,
    );

    while (true) {
      final result = await _fn.call({
        'systemPrompt': systemPrompt,
        'tools': settleTools,
        'messages': _history.map((m) => m.toJson()).toList(),
      });

      final data = Map<String, dynamic>.from(result.data as Map);
      final stopReason = data['stop_reason'] as String?;
      final contentBlocks = List<Map<String, dynamic>>.from(
        (data['content'] as List).map((e) => Map<String, dynamic>.from(e as Map)),
      );

      if (stopReason == 'tool_use') {
        _history.add(AgentMessage(role: 'assistant', content: contentBlocks));

        final toolResults = <Map<String, dynamic>>[];

        for (final block in contentBlocks) {
          if (block['type'] != 'tool_use') continue;

          final toolName = block['name'] as String;
          final toolInput =
              Map<String, dynamic>.from(block['input'] as Map);
          final toolUseId = block['id'] as String;

          String toolResult;
          try {
            toolResult = await _executeTool(toolName, toolInput);
          } catch (e) {
            toolResult = 'Error: $e';
          }

          toolResults.add({
            'type': 'tool_result',
            'tool_use_id': toolUseId,
            'content': toolResult,
          });
        }

        _history.add(AgentMessage(role: 'user', content: toolResults));
      } else {
        final text = contentBlocks
            .where((b) => b['type'] == 'text')
            .map((b) => b['text'] as String)
            .join('\n');

        _history.add(AgentMessage(role: 'assistant', content: text));
        await _persistHistory(text);
        return text;
      }
    }
  }

  Future<String> _executeTool(String name, Map<String, dynamic> input) async {
    switch (name) {
      case 'add_expense':
        await onAddExpense(input);
        return 'Expense added successfully: ${input['name']} ${input['amount']} ${input['currency']}';

      case 'add_savings_contribution':
        await onAddSavings(
          input['goalName'] as String,
          (input['amount'] as num).toDouble(),
          input['currency'] as String,
        );
        return 'Savings updated for goal: ${input['goalName']}';

      case 'get_financial_summary':
        final summary = await onGetSummary(
          input['period'] as String,
          start: input['startDate'] as String?,
          end: input['endDate'] as String?,
          groupBy: input['groupBy'] as String?,
        );
        return jsonEncode(summary);

      default:
        return 'Unknown tool: $name';
    }
  }

  Future<void> _persistHistory(String lastReply) async {
    if (_conversationId == null) return;

    final preview = lastReply.length > 80
        ? '${lastReply.substring(0, 80)}...'
        : lastReply;

    try {
      await _conversationsRef.doc(_conversationId).update({
        'messages': _history.map((m) => m.toJson()).toList(),
        'preview': preview,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error persisting conversation: $e');
    }
  }

  void clearHistory() {
    _history.clear();
    _conversationId = null;
  }

  /// Stream of all conversations for the conversation list
  Stream<List<Map<String, dynamic>>> conversationsStream() {
    return _conversationsRef
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return {
                'id': doc.id,
                'title': data['title'] ?? '',
                'preview': data['preview'] ?? '',
                'updatedAt': data['updatedAt'],
              };
            }).toList());
  }

  /// Delete a conversation
  Future<void> deleteConversation(String conversationId) async {
    await _conversationsRef.doc(conversationId).delete();
  }

  /// Get user-visible messages only (filter out tool calls / tool results)
  List<AgentMessage> get visibleMessages {
    return _history.where((m) {
      if (m.content is String) return true;
      if (m.content is List) {
        final list = m.content as List;
        if (list.isEmpty) return false;
        final first = list.first;
        if (first is Map) {
          return first['type'] == 'text';
        }
      }
      return false;
    }).toList();
  }
}
