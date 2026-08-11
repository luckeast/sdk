import 'dart:async';

import '../models/ai_chat_record.dart';
import 'doubao_ai_service.dart';

/// AI pet assistant service using Doubao API.
/// Provides general pet-care knowledge instead of professional diagnosis.
class AiVetService {
  final DoubaoAiService _doubao = DoubaoAiService();

  /// Predefined responses for offline fallback.
  final Map<String, String> _presetResponses = {
    'dog vomit yellow':
        'Yellow vomit in dogs often indicates bile, which can happen when their stomach is empty. If it\'s occasional and your dog seems otherwise normal, it\'s usually not concerning. However, if vomiting persists, contains blood, or is accompanied by lethargy or loss of appetite, contact your vet immediately.',
    'cat hair loss':
        'Some shedding is normal, but excessive hair loss in cats can indicate stress, allergies, parasites, or nutritional deficiencies. Check for bald patches, skin irritation, or changes in behavior. If the hair loss is significant or accompanied by other symptoms, schedule a vet visit.',
    'puppy food':
        'Puppies need specially formulated puppy food until about 12 months (24 months for large breeds). Look for AAFCO-approved puppy formulas with high-quality protein. Feed 3-4 small meals daily until 6 months, then transition to 2 meals.',
    'cat water':
        'Cats should drink about 3.5-4.5 ounces of water per 5 pounds of body weight daily. If your cat drinks significantly more or less, it could indicate kidney issues, diabetes, or other health problems. Always ensure fresh water is available.',
    'dog exercise':
        'Most adult dogs need 30 minutes to 2 hours of exercise daily, depending on breed, age, and health. Puppies and seniors need less. Mix walks, playtime, and mental stimulation activities.',
    'cat vomiting':
        'Occasional vomiting in cats (hairballs) is common. However, frequent vomiting, especially with other symptoms like diarrhea or lethargy, requires veterinary attention. Ensure your cat is hydrated.',
    'puppy vaccine':
        'Core puppy vaccines typically include DHPP (distemper, hepatitis, parainfluenza, parvovirus) and rabies. The first round starts at 6-8 weeks, with boosters every 3-4 weeks until 16 weeks.',
    'dog diarrhea':
        'Mild diarrhea in dogs often resolves within 24 hours. Withhold food for 12 hours, then feed a bland diet (boiled chicken and rice). If diarrhea persists beyond 24 hours, contains blood, or is accompanied by vomiting, see a vet.',
    'cat not eating':
        'Loss of appetite in cats can be serious, especially if it lasts more than 24 hours. Cats can develop fatty liver disease quickly. Check for dental issues, stress, or illness. Contact your vet if appetite doesn\'t return.',
    'dog scratching':
        'Excessive scratching can indicate fleas, allergies, dry skin, or infections. Check for visible parasites, red skin, or hot spots. Regular grooming and flea prevention help. Persistent scratching needs veterinary evaluation.',
  };

  /// Ask the AI vet assistant a question.
  Future<AiChatRecord> askQuestion({
    required String petId,
    required String question,
  }) async {
    try {
      final answer = await _askAi(question);
      return AiChatRecord(
        chatId: 'chat_${DateTime.now().millisecondsSinceEpoch}',
        petId: petId,
        question: question,
        answer: answer,
        createdAt: DateTime.now(),
      );
    } catch (e) {
      await Future.delayed(const Duration(milliseconds: 500));
      final answer = _generateAnswer(question);
      return AiChatRecord(
        chatId: 'chat_${DateTime.now().millisecondsSinceEpoch}',
        petId: petId,
        question: question,
        answer: answer,
        createdAt: DateTime.now(),
      );
    }
  }

  Stream<String> askQuestionStream({required String question}) async* {
    try {
      await for (final chunk in _doubao.streamChatCompletion(
        messages: _buildMessages(question),
        temperature: 0.7,
        maxTokens: 800,
      )) {
        yield chunk;
      }
    } catch (_) {
      final fallback = _generateAnswer(question);
      for (final chunk in _chunkFallback(fallback)) {
        yield chunk;
        await Future<void>.delayed(const Duration(milliseconds: 28));
      }
    }
  }

  Future<String> _askAi(String question) async {
    return await _doubao.chatCompletion(
      messages: _buildMessages(question),
      temperature: 0.7,
      maxTokens: 800,
    );
  }

  List<Map<String, dynamic>> _buildMessages(String question) {
    return [
      {
        'role': 'system',
        'content':
            '''You are Vymra Pet Companion Assistant, a warm and knowledgeable pet encyclopedia.

Important guidelines:
- Never present yourself as a veterinarian, doctor, clinic, or diagnostic authority
- You can answer pet-related questions about care, nutrition, habits, training, grooming, behavior, and general wellness
- Be practical, calm, and easy to understand
- When symptoms sound urgent or dangerous, clearly recommend seeing a licensed veterinarian promptly
- Avoid definitive diagnoses and avoid pretending you examined the pet
- End every response with: "_For general pet-care information only, not a professional veterinary diagnosis._"
- Keep responses concise, usually 2-4 short paragraphs''',
      },
      {'role': 'user', 'content': question},
    ];
  }

  String _generateAnswer(String question) {
    final lowerQuestion = question.toLowerCase();

    for (final entry in _presetResponses.entries) {
      if (lowerQuestion.contains(entry.key)) {
        return '${entry.value} _For general pet-care information only, not a professional veterinary diagnosis._';
      }
    }

    if (lowerQuestion.contains('food') ||
        lowerQuestion.contains('eat') ||
        lowerQuestion.contains('meal')) {
      return 'Nutrition is crucial for your pet\'s health. Ensure a balanced diet appropriate for their age, size, and activity level. Look for high-quality ingredients and AAFCO-approved formulas. If you have specific dietary concerns, consult your veterinarian for personalized recommendations. _For general pet-care information only, not a professional veterinary diagnosis._';
    }

    if (lowerQuestion.contains('water') || lowerQuestion.contains('drink')) {
      return 'Proper hydration is essential. Most pets need about 1 ounce of water per pound of body weight daily. Monitor water intake changes, as increased or decreased drinking can signal health issues. Always provide fresh, clean water. _For general pet-care information only, not a professional veterinary diagnosis._';
    }

    if (lowerQuestion.contains('exercise') ||
        lowerQuestion.contains('walk') ||
        lowerQuestion.contains('activity')) {
      return 'Regular exercise keeps pets physically and mentally healthy. The amount varies by species, breed, age, and health condition. For dogs, 30 minutes to 2 hours daily is typical. For cats, provide interactive play sessions. Always watch for signs of overexertion. _For general pet-care information only, not a professional veterinary diagnosis._';
    }

    if (lowerQuestion.contains('vaccine') ||
        lowerQuestion.contains('shot') ||
        lowerQuestion.contains('deworm')) {
      return 'Vaccinations and regular deworming are essential preventive care. Core vaccines protect against serious diseases, while non-core vaccines depend on lifestyle and risk factors. Keep a vaccination record and follow your vet\'s recommended schedule. _For general pet-care information only, not a professional veterinary diagnosis._';
    }

    if (lowerQuestion.contains('sleep') || lowerQuestion.contains('tired')) {
      return 'Sleep needs vary: adult dogs sleep 12-14 hours, puppies and seniors up to 18-20 hours. Cats typically sleep 12-16 hours daily. Changes in sleep patterns could indicate stress, illness, or pain. Monitor any sudden changes. _For general pet-care information only, not a professional veterinary diagnosis._';
    }

    if (lowerQuestion.contains('weight') ||
        lowerQuestion.contains('fat') ||
        lowerQuestion.contains('obese')) {
      return 'Maintaining a healthy weight is critical for longevity. You should be able to feel your pet\'s ribs without pressing hard. If you\'re concerned about weight changes, consult your vet for a proper assessment and dietary plan. _For general pet-care information only, not a professional veterinary diagnosis._';
    }

    return 'That\'s a great question about your pet. I can help with general pet-care information, but every pet is unique. If this concern is persistent, severe, or unusual, it\'s best to check with a licensed veterinarian who can assess your pet directly. _For general pet-care information only, not a professional veterinary diagnosis._';
  }

  Iterable<String> _chunkFallback(String value) sync* {
    final RegExp chunkPattern = RegExp(r'.{1,24}(\s|$)', dotAll: true);
    for (final match in chunkPattern.allMatches(value)) {
      final String chunk = match.group(0) ?? '';
      if (chunk.isNotEmpty) {
        yield chunk;
      }
    }
  }
}
