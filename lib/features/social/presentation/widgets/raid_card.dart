import 'package:flutter/material.dart';
import '../../domain/models/raid_model.dart';
import 'package:intl/intl.dart';

class RaidCard extends StatelessWidget {
  final RaidModel raid;

  const RaidCard({super.key, required this.raid});

  @override
  Widget build(BuildContext context) {
    final color = raid.bossType.color;
    final remainingDays = raid.endDate.difference(DateTime.now()).inDays;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: 0.1),
              color.withValues(alpha: 0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    raid.bossType.emoji,
                    style: const TextStyle(fontSize: 32),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        raid.title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        remainingDays > 0 
                          ? "Noch $remainingDays Tage Zeit" 
                          : "Läuft heute ab!",
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Boss-HP",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  "${(raid.healthPercentage * 100).toInt()}% HP",
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: raid.healthPercentage,
                minHeight: 12,
                backgroundColor: color.withValues(alpha: 0.1),
                color: color,
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                "Noch ${raid.remainingSteps} Schritte bis zum Sieg!",
                style: const TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
