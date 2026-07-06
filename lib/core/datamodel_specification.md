# Technisches Datenmodell: Fit_Buddyy (Firestore NoSQL)

Dieses Dokument definiert die Datenbankarchitektur, die Synchronisationslogik und das Gamification-System für die Fit_Buddyy App.

## 1. Firestore Entitäten & Relationen

Wir nutzen eine optimierte NoSQL-Struktur, die auf schnelles Lesen (Read-Heavy) ausgelegt ist.

### A. User-Profil (`/users/{userId}`)
Zentrale Speicherung der Nutzerdaten.
*   **uid**: `String` (Eindeutige ID aus Firebase Auth)
*   **displayName**: `String` (Anzeigename)
*   **photoUrl**: `String?` (URL zum Firebase Storage oder Google-Profilbild)
*   **currentLevel**: `int` (Aktuelles Level, startet bei 1)
*   **totalXP**: `int` (Gesammelte Erfahrungspunkte)
*   **groupIds**: `List<String>` (Referenzen auf Gruppen, in denen der Nutzer Mitglied ist)
*   **dailyStepGoal**: `int` (Individuelles Ziel, Standard: 10.000)

### B. Aktivitäten & Schritte (`/users/{userId}/activities/{date}`)
Um Queries effizient zu halten, speichern wir tägliche Daten in einer Unter-Collection. Die Dokument-ID ist das Datum im Format `YYYY-MM-DD`.
*   **steps**: `int` (Anzahl der Schritte)
*   **manualWorkouts**: `int` (Manuell eingetragene Einheiten)
*   **lastSync**: `Timestamp` (Zeitpunkt der letzten Cloud-Synchronisation)

### C. Gruppen & Leaderboards (`/groups/{groupId}`)
*   **name**: `String` (Name der Abteilung/Gruppe)
*   **inviteCode**: `String` (Eindeutiger 6-stelliger Code zum Beitreten)
*   **memberIds**: `List<String>` (Liste aller UIDs der Mitglieder)
*   **memberData**: `Map<String, Map>` (Redundante Speicherung von `displayName`, `photoUrl` und `totalXP` für die direkte Anzeige des Leaderboards)

### D. Chat-Funktion (`/groups/{groupId}/messages/{messageId}`)
Jede Gruppe hat eine Unter-Collection für Nachrichten.
*   **senderId**: `String` (UID des Senders)
*   **senderName**: `String` (Anzeigename des Senders zum Zeitpunkt der Nachricht)
*   **text**: `String` (Inhalt)
*   **timestamp**: `Timestamp` (Server-Zeitstempel für korrekte Sortierung)

### E. Dungeons & Boss-Kämpfe (`/groups/{groupId}/dungeons/{dungeonId}`)
Gruppenweite Events, bei denen Schritte in Schaden umgewandelt werden.
*   **bossName**: `String` (z.B. "Kalorien-König")
*   **bossType**: `String` (Visualisierungstyp: Feuer, Eis, Erde)
*   **maxHp**: `int` (Gesamtschritte, die die Gruppe erreichen muss)
*   **currentHp**: `int` (Verbleibende Schritte bis zum Sieg)
*   **startDate**: `Timestamp` (Beginn der Herausforderung)
*   **endDate**: `Timestamp` (Deadline)
*   **status**: `String` (`active`, `defeated`, `failed`)
*   **participants**: `Map<String, int>` (Beitrag pro Nutzer: `uid -> damage_dealt`)
*   **rewards**: `Map<String, dynamic>` (XP und Item-Drops nach Sieg)

### F. Inventar & Items (`/users/{userId}/inventory/{itemId}`)
*   **name**: `String` (z.B. "Goldener Laufschuh")
*   **type**: `String` (Ausrüstung, Verbrauchsgut)
*   **rarity**: `String` (common, rare, epic, legendary)
*   **bonusType**: `String` (z.B. "xp_multiplier", "step_boost")
*   **bonusValue**: `double` (Stärke des Effekts)

---

## 2. Media-Speicherung (Firebase Storage)

Profilbilder werden im Firebase Storage abgelegt, um die Datenbank klein zu halten:

*   **Pfad**: `/users/{userId}/profile.jpg`
*   **Workflow**: 
    1. Nutzer wählt Bild (ImagePicker).
    2. Bild wird hochgeladen und überschreibt die alte Datei.
    3. Die `photoUrl` im Firestore User-Dokument wird aktualisiert.
    4. Optional: Hintergrund-Job aktualisiert `photoUrl` in allen `memberData` der Gruppen des Nutzers.

---

## 3. Synchronisation & Offline-Caching

Das System folgt dem **Offline-First-Prinzip**:

1.  **Lokal (Hive/Isar)**: Live-Schrittdaten werden sekündlich lokal gepuffert. Dies schont den Akku und reduziert Firestore-Schreibkosten.
2.  **Cloud-Sync (Firestore Persistence)**: Firestore ist so konfiguriert, dass es Daten lokal zwischenspeichert. Sobald eine Internetverbindung besteht, werden Änderungen automatisch im Hintergrund synchronisiert.
3.  **Batch-Updates**: XP-Gutschriften erfolgen über `Write Batches`, um sicherzustellen, dass Profil-Updates und Aktivitäts-Logs atomar (ganz oder gar nicht) durchgeführt werden.

---

## 4. Gamification- & Level-Logik

Die XP-Berechnung folgt einer festen mathematischen Regel:

| Aktion | Belohnung (XP) |
| :--- | :--- |
| **Schritte** | $10 \text{ Schritte} = 1 \text{ XP}$ (z.B. 10.000 Schritte = 1.000 XP) |
| **Manuelles Workout** | $500 \text{ XP}$ pauschal |
| **Ziel erreicht** | $200 \text{ XP}$ Bonus bei Erreichen des `dailyStepGoal` |
| **Boss besiegt** | $1.000 - 5.000 \text{ XP}$ (je nach Schwierigkeit für alle Teilnehmer) |

**Boss-Kampf Mechanik:**
*   **Schaden**: Jeder in der App synchronisierte Schritt eines Mitglieds reduziert die `currentHp` des aktiven Gruppen-Bosses um 1 Punkt.
*   **Sieg**: Wenn `currentHp <= 0` vor Ablauf der `endDate`, erhalten alle Teilnehmer XP-Belohnungen.

**Level-Kurve:**
Die benötigten XP für das nächste Level berechnen sich nach:
$$\text{XP-Schwelle} = \text{Level}^2 \times 1000$$
*(Beispiel: Level 2 benötigt 4.000 XP, Level 3 benötigt 9.000 XP)*

---

## 5. Sicherheit & Validierung (Firestore Rules)

Um das Portfolio akademisch abzurunden, werden folgende Regeln implementiert:

```javascript
service cloud.firestore {
  match /databases/{database}/documents {
    // Nutzerprofil: Nur der Besitzer darf schreiben, alle in der gleichen Gruppe dürfen lesen
    match /users/{userId} {
      allow write: if request.auth != null && request.auth.uid == userId;
      allow read: if request.auth != null;
    }
    
    // Chat: Nur Mitglieder der Gruppe dürfen lesen und schreiben
    match /groups/{groupId}/messages/{msgId} {
      allow read, write: if request.auth != null && 
        request.auth.uid in get(/databases/$(database)/documents/groups/$(groupId)).data.memberIds;
    }
  }
}
```
