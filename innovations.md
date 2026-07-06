# FitBuddy Innovations-Fahrplan

Dieses Dokument beschreibt die geplanten innovativen Features für FitBuddy, um die Nutzerbindung und das Gruppenerlebnis zu steigern.

## 📅 Fortschritt: Woche 11. - 17. Mai

In dieser Woche haben wir den Fokus auf die soziale Dynamik und das Belohnungsgefühl gelegt:

*   **Großes Architektur-Refactoring:**
    *   Umstellung auf "Feature-First" Struktur (`auth`, `home`, `social`, `workout`).
    *   Einführung des Repository-Patterns für saubere Firebase-Anbindung.
*   **Einführung von "Group Boss Raids" (Idee 2):**
    *   Automatisches wöchentliches Boss-Event für jede Gruppe.
    *   Live-HP-Balken, der durch reale Schritte der Mitglieder sinkt.
    *   Zuweisung zufälliger Boss-Typen (Drache, Zombie, Werwolf, Riese) per Emoji.
*   **UX-Magic & Dopamin-Loop (Idee 5):**
    *   Konfetti-Animation bei Level-Up auf dem Dashboard.
    *   Haptisches Feedback (Vibration) bei Erreichen des Tagesziels.
    *   Spezielles Vibrations-Muster bei Level-Aufstieg.
*   **Test-Infrastruktur:**
    *   Implementierung eines Step-Simulators (+5000 Schritte), um Fortschritte und Effekte sofort prüfen zu können.

---

## 1. Group Boss Raids (Kooperativer Modus)
**Ziel:** Teamgeist statt nur Wettbewerb.
- **Konzept:** Eine Gruppe tritt gemeinsam gegen einen "Boss" an (z.B. einen Drachen mit 500.000 HP).
- **Mechanik:** 1 Schritt = 1 Schadenspunkt. Der Boss muss innerhalb einer Woche besiegt werden.
- **Belohnung:** Exklusive Badges oder Bonus-XP für alle Gruppenmitglieder.
- **Technische Umsetzung:**
    - Neue Firestore Collection `raids` innerhalb der Gruppen.
    - Aggregation der Schritte aller Mitglieder in Echtzeit.
    - `RaidCard` UI Komponente mit Boss-HP-Balken.

## 2. UX-Magic (Dopamin-Loop)
**Ziel:** Erfolge spürbar machen.
- **Haptik:** Gezieltes haptisches Feedback (Vibration) bei Erreichen des Tagesziels.
- **Visuals:** Konfetti-Effekte (`confetti` Paket) bei Level-Ups.
- **Micro-Interactions:** Sanfte Animationen beim Wechseln der Tage im Dashboard.

## 3. Ghost Run (Zeitreise)
**Ziel:** Vergleich mit der eigenen Bestleistung.
- **Konzept:** Im Dashboard wird nicht nur der Fortschritt von heute gezeigt, sondern dezent im Hintergrund der "Geist" der Vorwoche.
- **Mechanik:** "Du bist 400 Schritte hinter deinem Durchschnitt vom letzten Dienstag."
- **Motivation:** Nutzer dazu bringen, ihre eigenen Rekorde zu brechen.

## Nächste Schritte
1.  **Phase 1:** Implementierung von UX-Magic (Haptik & Konfetti).
2.  **Phase 2:** Datenmodell für Boss Raids und erste Test-Raids.
3.  **Phase 3:** Integration der Ghost-Run Logik im Dashboard-Provider.

