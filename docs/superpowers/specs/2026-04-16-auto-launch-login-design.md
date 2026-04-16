# Design: Avvio Automatico al Login

## Sommario

Aggiungere l'opzione "Apri all'accesso" in MiniMaxUsage, permettendo all'app di avviarsi automaticamente quando l'utente effettua il login su macOS, in modo silenzioso.

## Obiettivi

- L'utente può abilitare/disabilitare l'avvio automatico dalle Preferenze
- L'app si avvia silenziosamente senza notifiche quando l'utente fa login
- L'app rimane visibile nella menu bar dopo l'avvio automatico

## Implementazione

### API: SMAppService (macOS 13+)

Apple fornisce `SMAppService` come API moderna per gestire i login items. È l'approccio ufficiale e consigliato.

```swift
import ServiceManagement

// Abilita avvio al login
SMAppService.mainApp.register()

// Disabilita avvio al login
SMAppService.mainApp.unregister()

// Verifica stato attuale
let status = SMAppService.mainApp.status
// Valori: .enabled, .notRegistered, .requiresApproval
```

**Requisito minimo:** macOS 13+ (Ventura o successivo)

### Modifiche ai file esistenti

#### PreferencesWindow.swift

Aggiungere una checkbox nella sezione esistente delle preferenze:

```swift
// Checkbox "Apri all'accesso"
let launchAtLoginCheckbox = NSButton(checkboxWithTitle: "Apri MiniMaxUsage all'accesso", target: self, action: #selector(toggleLaunchAtLogin))

@objc func toggleLaunchAtLogin(_ sender: NSButton) {
    let enable = sender.state == .on
    if enable {
        SMAppService.mainApp.register()
    } else {
        SMAppService.mainApp.unregister()
    }
}
```

**Nota:** `SMAppService.mainApp.register()` richiede che l'app sia firmata correttamente (funziona con la build DMG). Per development locale potrebbe mostrare `.requiresApproval` — in quel caso mostrare un messaggio all'utente di approvare in Sistema > Login > Elementi.

### UX / Flusso

1. **Utente apre Preferenze**
2. **Vede la checkbox "Apri MiniMaxUsage all'accesso"** (spuntata o no in base allo stato corrente)
3. **Toggle della checkbox** → chiamata a `register()` o `unregister()`
4. **Se lo stato è `.requiresApproval`** → l'utente vede un messaggio: " Vai su Sistema > Login > Elementi per approvare"

### Comportamento all'avvio

Quando l'app viene lanciata automaticamente al login:
- **Nessuna notifica** — l'app parte silenziosamente
- **Si mostra nella menu bar** — come sempre
- **Nessun comportamento speciale** — l'app funziona normalmente

### Gestione errori

| Scenario | Comportamento |
|----------|---------------|
| `SMAppService.mainApp.status == .requiresApproval` | Mostra avviso con istruzioni |
| `register()` fallisce | Log errore, checkbox resta disabilitato |
| macOS < 13 | Checkbox nascosta (non applicabile) |

## Test

1. Verificare che la checkbox appaia nelle Preferenze
2. Toggle on → `SMAppService.mainApp.status` ritorna `.enabled`
3. Toggle off → `SMAppService.mainApp.status` ritorna `.notRegistered`
4. Riavviare il Mac e verificare che l'app si apra automaticamente
5. Verificare che non ci siano notifiche all'avvio automatico

## Dipendenze

- macOS 13.0+ (il progetto già richiede macOS 14 secondo README, quindi nessun problema)
- ServiceManagement framework (di sistema)
