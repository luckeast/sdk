import 'package:flutter/material.dart';
import '../localization/app_strings.dart';
import '../models/ai_chat_record.dart';
import '../repositories/ai_chat_repository.dart';
import '../services/ai_vet_service.dart';

/// Provider for managing AI vet chat state.
class AiChatProvider extends ChangeNotifier {
  final AiChatRepository _repository;
  final AiVetService _aiService;
  List<AiChatRecord> _chats = [];
  bool _isLoading = false;
  String? _error;
  String? _streamingQuestion;
  String _streamingAnswer = '';

  AiChatProvider(this._repository, this._aiService);

  List<AiChatRecord> get chats => List.unmodifiable(_chats);
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get streamingQuestion => _streamingQuestion;
  String get streamingAnswer => _streamingAnswer;
  bool get isStreaming => _streamingQuestion != null;

  Future<void> loadChats(String petId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _chats = await _repository.getChatsByPet(petId);
    } catch (e) {
      _chats = [];
      _error = AppStrings.tr('Failed to load chat history');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void reset() {
    _chats = [];
    _streamingQuestion = null;
    _streamingAnswer = '';
    _error = null;
    notifyListeners();
  }

  Future<void> askQuestion(String petId, String question) async {
    await askQuestionStream(petId, question);
  }

  Future<AiChatRecord?> askQuestionAndGetAnswer(
    String petId,
    String question,
  ) async {
    if (question.trim().isEmpty) {
      return null;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final AiChatRecord record = await _aiService.askQuestion(
        petId: petId,
        question: question.trim(),
      );

      await _repository.saveChat(record);
      _chats.insert(0, record);
      _error = null;
      return record;
    } catch (e) {
      _error = AppStrings.tr('Failed to get response. Please try again.');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<AiChatRecord?> askQuestionStream(String petId, String question) async {
    if (question.trim().isEmpty) {
      return null;
    }

    _isLoading = true;
    _error = null;
    _streamingQuestion = question.trim();
    _streamingAnswer = '';
    notifyListeners();

    try {
      await for (final chunk in _aiService.askQuestionStream(
        question: question.trim(),
      )) {
        _streamingAnswer += chunk;
        notifyListeners();
      }

      final record = AiChatRecord(
        chatId: 'chat_${DateTime.now().millisecondsSinceEpoch}',
        petId: petId,
        question: question.trim(),
        answer: _streamingAnswer.trim(),
        createdAt: DateTime.now(),
      );

      await _repository.saveChat(record);
      _chats.insert(0, record);
      _streamingQuestion = null;
      _streamingAnswer = '';
      return record;
    } catch (e) {
      _error = AppStrings.tr('Failed to get response. Please try again.');
      _streamingQuestion = null;
      _streamingAnswer = '';
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggleBookmark(String chatId) async {
    final index = _chats.indexWhere((c) => c.chatId == chatId);
    if (index < 0) return;

    final updated = _chats[index].copyWith(
      isBookmarked: !_chats[index].isBookmarked,
    );

    try {
      await _repository.saveChat(updated);
      _chats[index] = updated;
      notifyListeners();
    } catch (e) {
      _error = AppStrings.tr('Failed to update bookmark');
      notifyListeners();
    }
  }

  Future<void> deleteChat(String chatId) async {
    try {
      await _repository.deleteChat(chatId);
      _chats.removeWhere((c) => c.chatId == chatId);
      notifyListeners();
    } catch (e) {
      _error = AppStrings.tr('Failed to delete chat');
      notifyListeners();
    }
  }
}
