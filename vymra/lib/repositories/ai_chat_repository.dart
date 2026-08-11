import 'package:hive/hive.dart';
import '../models/ai_chat_record.dart';

/// Repository interface for AI chat record CRUD operations.
abstract class AiChatRepository {
  Future<List<AiChatRecord>> getChatsByPet(String petId);
  Future<List<AiChatRecord>> getBookmarkedChats(String petId);
  Future<AiChatRecord?> getChat(String chatId);
  Future<void> saveChat(AiChatRecord chat);
  Future<void> deleteChat(String chatId);
  Future<List<AiChatRecord>> searchChats(String petId, String query);
}

/// Hive implementation of AiChatRepository.
class HiveAiChatRepository implements AiChatRepository {
  static const String _boxName = 'ai_chat_records';
  Box<AiChatRecord>? _box;

  Future<Box<AiChatRecord>> get _boxInstance async {
    if (_box != null && !_box!.isOpen) {
      _box = null;
    }
    _box ??= await Hive.openBox<AiChatRecord>(_boxName);
    return _box!;
  }

  @override
  Future<List<AiChatRecord>> getChatsByPet(String petId) async {
    final box = await _boxInstance;
    return box.values
        .where((c) => c.petId == petId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<List<AiChatRecord>> getBookmarkedChats(String petId) async {
    final box = await _boxInstance;
    return box.values
        .where((c) => c.petId == petId && c.isBookmarked)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<AiChatRecord?> getChat(String chatId) async {
    final box = await _boxInstance;
    return box.get(chatId);
  }

  @override
  Future<void> saveChat(AiChatRecord chat) async {
    final box = await _boxInstance;
    await box.put(chat.chatId, chat);
  }

  @override
  Future<void> deleteChat(String chatId) async {
    final box = await _boxInstance;
    await box.delete(chatId);
  }

  @override
  Future<List<AiChatRecord>> searchChats(String petId, String query) async {
    final all = await getChatsByPet(petId);
    final lowerQuery = query.toLowerCase();
    return all
        .where((c) =>
            c.question.toLowerCase().contains(lowerQuery) ||
            c.answer.toLowerCase().contains(lowerQuery))
        .toList();
  }
}
