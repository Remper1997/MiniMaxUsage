# Design: Auto-Update with Sparkle

## Sommario

Aggiungere un sistema di aggiornamento automatico usando Sparkle 2.x, con controllo automatico in background e dialog popup per l'utente.

## Obiettivi

- Utente può abilitare/disabilitare controllo automatico
- Utente può forzare controllo manuale
- Dialog popup quando un update è disponibile
- Usa GitHub Releases come server update

## Implementazione

### Framework: Sparkle 2.x

Sparkle è lo standard de facto per aggiornamenti macOS. Supporta:
- Download in background
- Firma codice per sicurezza
- GitHub Releases come update server
- Dialog di conferma utente

### Dipendenza: Sparkle via SPM

```swift
// Package.swift o Xcode SPM
.package(url: "https://github.com/sparkle-project/Sparkle", from: "2.0.0")
```

### Comportamento

1. **Controllo automatico:** Ogni 24 ore se abilitato
2. **Update disponibile:** Dialog popup chiede conferma
3. **Utente accetta:** Download + riavvio app
4. **Utente rifiuta:** Niente, riprova al prossimo ciclo

### UI: Preferenze

Sezione "Updates" in PreferencesWindow:

```
┌─────────────────────────────────┐
│  Preferences                    │
├─────────────────────────────────┤
│                                │
│  Updates                       │
│  [x] Check for updates        │
│      automatically            │
│                                │
│  Last checked: 2 hours ago    │
│  [Check for Updates]          │
│                                │
└─────────────────────────────────┘
```

### Files da modificare

- **PreferencesWindow.swift:** Aggiungere sezione Updates con checkbox e pulsante
- **AppDelegate.swift:** Inizializzare Sparkle updater
- **SettingsHelper.swift:** Aggiungere setting per auto-update

### Hosting update

GitHub Releases già configurato funziona come update server. Sparkle usa il feed RSS standard.

### Flusso tecnico

1. AppDelegate inizializza `SPUStandardUpdaterController`
2. Se `SettingsHelper.autoUpdateEnabled`, avvia timer per controllo ogni 24h
3. Quando update disponibile, Sparkle mostra dialog di sistema
4. Click "Install" → Sparkle gestisce download e riavvio

## Test

1. Verificare che sezione Updates appaia in Preferenze
2. Toggle automatic update on/off
3. Click "Check for Updates" → Sparkle controlla
4. Mock un update disponibile → verifica dialog appare
5. Verificare che DMG sia correttamente firmato per Sparkle
