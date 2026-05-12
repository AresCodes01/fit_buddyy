# FitBuddy - AI Agent Guideline & Rules

Diese Datei definiert die Architektur-Standards und Verhaltensregeln für alle KI-gestützten Code-Generierungen in diesem Projekt.

## 1. Architektur-Prinzipien (Strengstens einzuhalten)
- **Feature-based Folder Structure:** Jedes Feature liegt in einem eigenen Ordner unter `lib/features/` (z.B. `lib/features/workout/`).
- **Layer-Trennung:** Jedes Feature ist unterteilt in:
  - `presentation/`: Widgets und UI-Logik.
  - `domain/`: Business-Logic-Modelle und Repository-Interfaces.
  - `data/`: Konkrete Repository-Implementierungen und Datenquellen (Firestore, Local Storage).
- **Repository Pattern:** Kein direkter Zugriff auf Firebase aus der UI. Datenzugriff erfolgt ausschließlich über Repositories.

## 2. State Management (Provider)
- **Tool:** Nutze das `provider` Paket.
- **Performance:** Nutze `context.select<T, R>()` anstelle von `context.watch<T>()`, um unnötige Rebuilds zu minimieren.
- **Trennung:** Logik gehört in den `ChangeNotifier` (oder `StateNotifier`), das UI bleibt deklarativ.

## 3. Tech-Stack & Framework Rules
- **Material 3:** Nutze konsequent Material 3 Komponenten und `ColorScheme`.
- **Typisierung:** Volle Null-Safety. Vermeide `dynamic`. Jede Methode muss einen Rückgabetyp haben.
- **Asynchronität:** Nutze `FutureOr` und `Streams` korrekt für Echtzeit-Updates im Live-Dashboard.

## 4. Spezifische Projekt-Features
- **Workout Tracking:** Nur manuelle Eingabe (keine Stoppuhr). Auswahl erfolgt über Kacheln (`SliverGrid`).
- **Gamification:** XP-, Level- und Streak-Updates müssen über atomare Firestore-Operationen (`WriteBatch` oder `runTransaction`) erfolgen.
- **Social Logic:** Jedes gespeicherte Workout muss einen Eintrag in der `group_feed` Collection triggern.

## 5. Kommunikations-Stil
- Kommentare im Code: Deutsch oder Englisch (nach Wahl des Nutzers).
- Erklärungen: Technisch präzise, Fokus auf Performance und Stabilität.
