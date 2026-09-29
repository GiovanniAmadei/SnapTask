# SnapTask Watch App

App Apple Watch completa per SnapTask con sincronizzazione dual-mode (Bluetooth + CloudKit).

## Funzionalità

### 📋 Task
- Lista task giornaliere con dettagli visibili
- Dettaglio task completo con subtask
- Creazione, modifica, eliminazione task
- Toggle completamento task e subtask

### ⏱️ Timer
- **Timer Semplice**: Cronometro libero come su iOS
- **Timer Pomodoro**: Configurabile all'avvio di ogni sessione
  - Durata focus personalizzabile
  - Durata break personalizzabile
  - Numero sessioni personalizzabile
  - Feedback aptico

### 🎁 Premi
- Lista premi con punti disponibili
- Riscatto premi
- Creazione, modifica, eliminazione premi

### 📊 Statistiche
- **Time Distribution**: Distribuzione tempo per categoria (come iOS)
- **Task Completion**: Tasso completamento con grafico
- **Streak**: Streak corrente e migliore

### ⚙️ Impostazioni
- Stato sincronizzazione
- Sync manuale
- Preferenze haptic e notifiche
- Info account

### ⌚ Complicazioni
- Circular: Task rimanenti
- Rectangular: Prossima task + streak
- Corner: Icona + conteggio
- Inline: "X tasks left"

## Sincronizzazione

### Dual-Mode Sync
1. **Bluetooth (WCSession)**: Quando iPhone è connesso
2. **CloudKit**: Fallback quando iPhone non raggiungibile

L'app sceglie automaticamente il metodo migliore.

## Setup in Xcode

### 1. Aggiungere Watch Target
1. File → New → Target
2. Seleziona "watchOS" → "App"
3. Nome: "SnapTaskWatch"
4. Bundle ID: `com.snaptask.app.watchkitapp`

### 2. Configurare Capabilities
- **CloudKit**: Stesso container dell'app iOS (`iCloud.com.snaptask.app`)
- **Background Modes**: Background App Refresh

### 3. Condividere Modelli
I modelli devono essere condivisi tra iOS e watchOS:
- `TodoTask.swift`
- `Category.swift`
- `Reward.swift`
- `PomodoroSettings.swift`
- `Subtask.swift`
- `Priority.swift`
- `Recurrence.swift`
- `TaskCompletion.swift`
- `TrackingSession.swift`
- `TrackingMode.swift`
- `RewardFrequency` (in Reward.swift)

Aggiungi questi file al target watchOS in "Target Membership".

### 4. Aggiungere WatchConnectivity all'app iOS
Inizializza `WatchConnectivityHandler.shared` nell'AppDelegate o SceneDelegate:

```swift
// In SnapTaskApp.swift
init() {
    _ = WatchConnectivityHandler.shared
}
```

### 5. Build & Run
1. Seleziona lo schema "SnapTaskWatch"
2. Seleziona un simulatore Apple Watch
3. Build and Run

## Struttura File

```
SnapTaskWatch/
├── SnapTaskWatchApp.swift
├── ContentView.swift
├── Info.plist
├── SnapTaskWatch.entitlements
├── Assets.xcassets/
├── Sync/
│   ├── WatchSyncManager.swift
│   ├── WatchConnectivityManager.swift
│   └── WatchCloudKitManager.swift
├── Models/
│   └── SharedModels.swift
├── Views/
│   ├── Tasks/
│   ├── Timer/
│   ├── Rewards/
│   ├── Statistics/
│   └── Settings/
└── Complications/
    └── SnapTaskComplication.swift
```

## Note Tecniche

- **watchOS minimo**: 10.0
- **Standalone**: Funziona anche senza iPhone
- **Digital Crown**: Per input numerici
- **Haptic Feedback**: Per azioni importanti
