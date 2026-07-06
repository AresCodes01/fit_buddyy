import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../features/auth/domain/models/user_model.dart';
import '../features/home/domain/models/daily_stats_model.dart';

class AiService {
  static final AiService _instance = AiService._internal();
  factory AiService() => _instance;
  AiService._internal();

  String? _apiKey;
  GenerativeModel? _model;

  void init(String apiKey) {
    _apiKey = apiKey.trim();
    // Der von dir gepostete cURL nutzt 'gemini-flash-latest'
    // Dies ist ein Alias für das neueste Flash-Modell.
    _model = GenerativeModel(
      model: 'gemini-flash-latest',
      apiKey: _apiKey!,
      requestOptions: const RequestOptions(apiVersion: 'v1beta'),
    );
    debugPrint("AI DEBUG: Initialized with gemini-flash-latest (v1beta)");
  }

  bool get isInitialized => _model != null;

  Future<String> generateDailyMotivation({
    required UserModel user,
    required List<DailyStatsModel> history,
    required int todaySteps,
  }) async {
    if (!isInitialized) return "Kein API Key konfiguriert. 🔑";

    final prompt = """
Du bist "Fit Buddyy", ein Fitness-Coach. 
Nutzer: ${user.displayName}, Ziel: ${user.goalValue}, Schritte heute: $todaySteps.
Antworte kurz auf Deutsch (max 2 Sätze) mit Emojis.
""";

    try {
      final response = await _model!.generateContent([Content.text(prompt)]);
      return response.text ?? "Bleib in Bewegung! 🚀";
    } catch (e) {
      debugPrint("AI ERROR (Motivation): $e");
      return "Ich bin gerade etwas außer Puste. Aber du schaffst das! 💪";
    }
  }

  Future<String> chatWithBuddy({
    required String userMessage,
    required UserModel user,
    required int todaySteps,
    List<Map<String, String>> history = const [],
  }) async {
    if (!isInitialized) return "Kein API Key konfiguriert. 🔑";

    final systemPrompt = """
Du bist "Fit Buddyy", ein motivierender Fitness-Coach. 
Daten des Nutzers:
- Name: ${user.displayName}
- Schritte heute: $todaySteps
- Tagesziel: ${user.goalValue}
- Level: ${user.level}
- Streak: ${user.streak} Tage

Antworte kurz, motivierend und auf Deutsch. Nutze Emojis.
""";

    try {
      // Konvertiere Chat-Historie in das Gemini-Format
      final contents = <Content>[
        Content.text(systemPrompt),
      ];

      for (var msg in history) {
        if (msg['role'] == 'user') {
          contents.add(Content.text("Nutzer: ${msg['content']}"));
        } else {
          contents.add(Content.text("Buddy: ${msg['content']}"));
        }
      }

      contents.add(Content.text("Nutzer: $userMessage"));

      final response = await _model!.generateContent(contents);
      return response.text ?? "Interessante Frage! 👟";
    } catch (e) {
      debugPrint("AI ERROR (Chat): $e");
      return "Ups, kleiner Schluckauf. Frag mich gleich nochmal! 😅";
    }
  }
}
