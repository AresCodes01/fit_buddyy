import 'package:flutter/material.dart';

enum ItemRarity {
  common,
  rare,
  epic,
  legendary;

  Color get color {
    switch (this) {
      case ItemRarity.common: return Colors.grey;
      case ItemRarity.rare: return Colors.blue;
      case ItemRarity.epic: return Colors.purple;
      case ItemRarity.legendary: return Colors.orange;
    }
  }

  String get label {
    switch (this) {
      case ItemRarity.common: return 'Gewöhnlich';
      case ItemRarity.rare: return 'Selten';
      case ItemRarity.epic: return 'Episch';
      case ItemRarity.legendary: return 'Legendär';
    }
  }
}

class ItemModel {
  final String id;
  final String name;
  final String emoji;
  final ItemRarity rarity;
  final String bonusType; // e.g., 'xp_multiplier'
  final double bonusValue;

  ItemModel({
    required this.id,
    required this.name,
    required this.emoji,
    required this.rarity,
    required this.bonusType,
    required this.bonusValue,
  });

  factory ItemModel.fromMap(Map<String, dynamic> map, String id) {
    return ItemModel(
      id: id,
      name: map['name'] ?? 'Unbekanntes Item',
      emoji: map['emoji'] ?? '📦',
      rarity: ItemRarity.values.firstWhere(
        (e) => e.name == (map['rarity'] ?? 'common'),
        orElse: () => ItemRarity.common,
      ),
      bonusType: map['bonusType'] ?? 'none',
      bonusValue: (map['bonusValue'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'emoji': emoji,
      'rarity': rarity.name,
      'bonusType': bonusType,
      'bonusValue': bonusValue,
    };
  }
}
