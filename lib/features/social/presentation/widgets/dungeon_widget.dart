import 'package:flutter/material.dart';
import '../../domain/models/raid_model.dart';

class DungeonWidget extends StatelessWidget {
  final RaidModel raid;

  const DungeonWidget({super.key, required this.raid});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              raid.bossType.color.withValues(alpha: 0.1),
              raid.bossType.color.withValues(alpha: 0.3),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "AKTIVER BOSS",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: raid.bossType.color,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      raid.title,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Text(
                  raid.bossType.emoji,
                  style: const TextStyle(fontSize: 40),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: raid.healthPercentage,
                    minHeight: 20,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(raid.bossType.color),
                  ),
                ),
                Positioned.fill(
                  child: Center(
                    child: Text(
                      "${(raid.healthPercentage * 100).toInt()}% HP",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        shadows: [Shadow(blurRadius: 2)],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Noch ${raid.remainingSteps} Schritte",
                  style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w500),
                ),
                Text(
                  "Endet in: ${raid.endDate.difference(DateTime.now()).inDays}T",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
