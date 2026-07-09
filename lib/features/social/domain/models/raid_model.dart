import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum BossType {
  dragon,
  giant,
  wolf,
  zombie;

  String get emoji {
    switch (this) {
      case BossType.dragon: return '🐲';
      case BossType.giant: return '👹';
      case BossType.wolf: return '🐺';
      case BossType.zombie: return '🧟';
    }
  }

  String get label {
    switch (this) {
      case BossType.dragon: return 'Drache';
      case BossType.giant: return 'Riese';
      case BossType.wolf: return 'Werwolf';
      case BossType.zombie: return 'Zombie';
    }
  }

  Color get color {
    switch (this) {
      case BossType.dragon: return Colors.redAccent;
      case BossType.giant: return Colors.brown;
      case BossType.wolf: return Colors.blueGrey;
      case BossType.zombie: return Colors.green;
    }
  }
}

class RaidModel {
  final String id;
  final String title;
  final int targetSteps;
  final int currentSteps;
  final DateTime endDate;
  final BossType bossType;
  final String status; // active, defeated, failed
  final Map<String, int> participants; // userId -> steps contributed
  final List<String> claimedBy; // users who claimed/saw the reward

  RaidModel({
    required this.id,
    required this.title,
    required this.targetSteps,
    required this.currentSteps,
    required this.endDate,
    required this.bossType,
    this.status = 'active',
    this.participants = const {},
    this.claimedBy = const [],
  });

  bool get isCompleted => status == 'defeated';
  double get healthPercentage => (1.0 - (currentSteps / targetSteps)).clamp(0.0, 1.0);
  int get remainingSteps => (targetSteps - currentSteps).clamp(0, targetSteps);

  factory RaidModel.fromMap(String id, Map<String, dynamic> map) {
    return RaidModel(
      id: id,
      title: map['title'] ?? 'Unbekannter Boss',
      targetSteps: map['targetSteps'] ?? 100000,
      currentSteps: map['currentSteps'] ?? 0,
      endDate: (map['endDate'] as Timestamp).toDate(),
      bossType: BossType.values.firstWhere(
        (e) => e.name == (map['bossType'] ?? 'dragon'),
        orElse: () => BossType.dragon,
      ),
      status: map['status'] ?? (map['isCompleted'] == true ? 'defeated' : 'active'),
      participants: Map<String, int>.from(map['participants'] ?? {}),
      claimedBy: List<String>.from(map['claimedBy'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'targetSteps': targetSteps,
      'currentSteps': currentSteps,
      'endDate': Timestamp.fromDate(endDate),
      'bossType': bossType.name,
      'status': status,
      'participants': participants,
      'claimedBy': claimedBy,
    };
  }
}
