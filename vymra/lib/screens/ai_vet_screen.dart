import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../localization/app_localizations.dart';
import '../providers/ai_chat_provider.dart';
import '../services/ai_consent_service.dart';
import '../theme/app_theme.dart';
import '../widgets/voice_text_field.dart';

/// AI pet companion chat screen.
class AiVetScreen extends StatefulWidget {
  final String petId;

  const AiVetScreen({super.key, required this.petId});

  @override
  State<AiVetScreen> createState() => _AiVetScreenState();
}

class _AiVetScreenState extends State<AiVetScreen> {
  final AiConsentService _consentService = AiConsentService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadChats();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final bool hasConsent = await _consentService.ensureConsent(context);
      if (!hasConsent && mounted) {
        await Navigator.of(context).maybePop();
      }
    });
  }

  Future<void> _loadChats() async {
    await context.read<AiChatProvider>().loadChats(widget.petId);
  }

  void _sendMessage([String? question]) async {
    final text = question ?? _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();
    FocusScope.of(context).unfocus();

    await context.read<AiChatProvider>().askQuestion(widget.petId, text);

    // Scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<AiChatProvider>();
    final chats = chatProvider.chats;
    final List<String> quickQuestions = <String>[
      context.tr('Why is my dog scratching so much?'),
      context.tr('What should I feed a picky cat?'),
      context.tr('How much exercise does a puppy need?'),
      context.tr('What vaccines are commonly needed?'),
      context.tr('How do I tell if my pet is stressed?'),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.smart_toy, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.tr('AI Vet'), style: TextStyle(fontSize: 16)),
                Text(
                  context.tr('Online • Pet topics and general guidance'),
                  style: AppTextStyles.label.copyWith(color: AppColors.success),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Disclaimer banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppColors.warning.withOpacity(0.1),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  color: AppColors.warning,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.tr(
                      'This assistant is a general pet-care helper. For diagnosis, emergencies, or treatment decisions, contact a licensed veterinarian.',
                    ),
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.warning,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Chat messages
          Expanded(
            child: chats.isEmpty && !chatProvider.isStreaming
                ? _EmptyChatView(
                    quickQuestions: quickQuestions,
                    onQuestionTap: _sendMessage,
                  )
                : ListView(
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.all(16),
                    children: _buildChatItems(chatProvider),
                  ),
          ),
          // Quick questions row
          if (chats.isEmpty)
            SizedBox(
              height: 44,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: quickQuestions.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      label: Text(quickQuestions[index]),
                      onPressed: () => _sendMessage(quickQuestions[index]),
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                      labelStyle: AppTextStyles.caption.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  );
                },
              ),
            ),
          // Input area
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Semantics(
                      identifier: 'chat_input_field',
                      child: VoiceTextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: context.tr(
                            'Ask anything about your pet...',
                          ),
                          filled: true,
                          fillColor: AppColors.background,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                        ),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Semantics(
                    identifier: 'chat_send_button',
                    child: GestureDetector(
                      onTap: chatProvider.isLoading
                          ? null
                          : () => _sendMessage(),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: chatProvider.isLoading
                              ? LinearGradient(
                                  colors: [
                                    AppColors.primary.withOpacity(0.5),
                                    AppColors.accent.withOpacity(0.5),
                                  ],
                                )
                              : AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: chatProvider.isLoading
                            ? const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(
                                      Colors.white,
                                    ),
                                  ),
                                ),
                              )
                            : const Icon(Icons.send, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyChatView extends StatelessWidget {
  final List<String> quickQuestions;
  final ValueChanged<String> onQuestionTap;

  const _EmptyChatView({
    required this.quickQuestions,
    required this.onQuestionTap,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(40),
            ),
            child: const Icon(Icons.smart_toy, color: Colors.white, size: 40),
          ),
          const SizedBox(height: 20),
          Text(context.tr('Pet Care Companion'), style: AppTextStyles.headline),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              context.tr(
                'Ask about nutrition, habits, grooming, behavior, routines, or everyday pet questions.',
              ),
              style: AppTextStyles.caption,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

extension on _AiVetScreenState {
  List<Widget> _buildChatItems(AiChatProvider chatProvider) {
    final List<Widget> widgets = [];

    if (chatProvider.isStreaming && chatProvider.streamingQuestion != null) {
      widgets.add(
        _ChatBubble(
          isUser: false,
          message: chatProvider.streamingAnswer.isEmpty
              ? context.tr('Thinking...')
              : chatProvider.streamingAnswer,
          time: DateTime.now(),
          isStreaming: true,
        ),
      );
      widgets.add(
        _ChatBubble(
          isUser: true,
          message: chatProvider.streamingQuestion!,
          time: DateTime.now(),
        ),
      );
    }

    for (final chat in chatProvider.chats) {
      widgets.add(
        _ChatBubble(isUser: false, message: chat.answer, time: chat.createdAt),
      );
      widgets.add(
        _ChatBubble(isUser: true, message: chat.question, time: chat.createdAt),
      );
    }

    return widgets;
  }
}

class _ChatBubble extends StatelessWidget {
  final bool isUser;
  final String message;
  final DateTime time;
  final bool isStreaming;

  const _ChatBubble({
    required this.isUser,
    required this.message,
    required this.time,
    this.isStreaming = false,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: isUser ? AppColors.primaryGradient : null,
          color: isUser ? null : AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          boxShadow: isUser
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isStreaming) ...[
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: isUser ? Colors.white70 : AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
            ],
            Flexible(
              child: Text(
                message,
                style: AppTextStyles.body.copyWith(
                  color: isUser ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
