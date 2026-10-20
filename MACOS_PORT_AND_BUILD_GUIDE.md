# Veyon per macOS — Documento Modifiche e Guida alla Compilazione

Questo documento descrive in dettaglio **tutte le modifiche e i file aggiunti** al repository per rendere Veyon nativamente supportato, compilabile e installabile su **macOS** (sia architetture Apple Silicon **ARM64** che **x86_64**), insieme alla **guida completa passo-passo alla compilazione, creazione dei pacchetti (DMG/PKG) e installazione**.

---

## Indice

1. [Panoramica dell'Integrazione macOS](#1-panoramica-dellintegrazione-macos)
2. [Elenco Completo delle Modifiche al Codice Esistente](#2-elenco-completo-delle-modifiche-al-codice-esistente)
3. [Nuovi Moduli e File Creati](#3-nuovi-moduli-e-file-creati)
   - [3.1 Plugin di Piattaforma macOS (`plugins/platform/macos/`)](#31-plugin-di-piattaforma-macos-pluginsplatformmacos)
   - [3.2 Plugin Server VNC ScreenCaptureKit (`plugins/vncserver/screencapturekit/`)](#32-plugin-server-vnc-screencapturekit-pluginsvncserverscreencapturekit)
4. [Architettura Tecnica macOS](#4-architettura-tecnica-macos)
   - [4.1 Cattura Schermo e Permessi TCC (Privacy)](#41-cattura-schermo-e-permessi-tcc-privacy)
   - [4.2 Servizio di Sistema LaunchDaemon (`launchd`)](#42-servizio-di-sistema-launchdaemon-launchd)
   - [4.3 Gestione Energetica e Prevenzione Sleep (IOKit)](#43-gestione-energetica-e-prevenzione-sleep-iokit)
   - [4.4 Monitoraggio Sessioni e Fast User Switching (SCDynamicStore)](#44-monitoraggio-sessioni-e-fast-user-switching-scdynamicstore)
   - [4.5 Gestione Utenti e Gruppi (OpenDirectory)](#45-gestione-utenti-e-gruppi-opendirectory)
5. [Guida alla Compilazione (Build) e Installazione su macOS](#5-guida-alla-compilazione-build-e-installazione-su-macos)
   - [5.1 Prerequisiti](#51-prerequisiti)
   - [5.2 Installazione Dipendenze con Homebrew](#52-installazione-dipendenze-con-homebrew)
   - [5.3 Configurazione CMake](#53-configurazione-cmake)
   - [5.4 Compilazione](#54-compilazione)
   - [5.5 Installazione nel Sistema](#55-installazione-nel-sistema)
   - [5.6 Creazione Pacchetti di Distribuzione (DMG / PKG)](#56-creazione-pacchetti-di-distribuzione-dmg--pkg)
   - [5.7 Configurazione Post-Installazione e Permessi](#57-configurazione-post-installazione-e-permessi)

---

## 1. Panoramica dell'Integrazione macOS

Fino ad ora Veyon era supportato unicamente su Windows e Linux. L'ecosistema macOS richiede l'integrazione di framework nativi di sistema (Cocoa, CoreGraphics, ScreenCaptureKit, IOKit, SystemConfiguration, OpenDirectory, ServiceManagement) e il rispetto delle rigide politiche di sicurezza Apple (TCC - Transparency, Consent, and Control, sandboxing e firma del codice).

L'implementazione segue l'architettura modulare di Veyon:
1. **Plugin di Piattaforma Nativo (`macos-platform`)**: Implementa le 7 interfacce essenziali di sistema richieste da `PlatformPluginInterface`.
2. **Plugin VNC Nativo (`screencapturekit-vnc-server`)**: Fornisce lo streaming dello schermo in tempo reale per la sessione grafica `Aqua` e inietta input mouse/tastiera remoti.
3. **Integrazione `launchd`**: Sostituisce il modello systemd/Windows SCM per l'esecuzione del demone headless `veyon-service` come root.

---

## 2. Elenco Completo delle Modifiche al Codice Esistente

Sono stati modificati 6 file principali del sistema di configurazione e build:

### 2.1 [CMakeLists.txt](file:///c:/Users/raffa/Desktop/Nuova%20cartella%20(3)/veyon/CMakeLists.txt)
* **Separazione corretta tra Linux e macOS**: macOS viene riconosciuto da CMake come `UNIX`, causando erroneamente l'impostazione di `VEYON_BUILD_LINUX`. La condizione è stata corretta con `if(UNIX AND NOT ANDROID AND NOT APPLE)`.
* **Abilitazione di Objective-C++**: Aggiunta la direttiva `enable_language(OBJCXX)` quando `APPLE` è vero.

```diff
 if(APPLE)
 	set(VEYON_BUILD_APPLE 1)
+	enable_language(OBJCXX)
 endif()
-if(UNIX AND NOT ANDROID)
+if(UNIX AND NOT ANDROID AND NOT APPLE)
 	set(VEYON_BUILD_LINUX 1)
 endif()
```

### 2.2 [plugins/platform/CMakeLists.txt](file:///c:/Users/raffa/Desktop/Nuova%20cartella%20(3)/veyon/plugins/platform/CMakeLists.txt)
* Aggiunta l'inclusione della sottodirectory `macos` quando `VEYON_BUILD_APPLE` è attivo:

```diff
 if(VEYON_BUILD_LINUX)
 	add_subdirectory(linux)
 endif()
+
+if(VEYON_BUILD_APPLE)
+	add_subdirectory(macos)
+endif()
```

### 2.3 [plugins/vncserver/CMakeLists.txt](file:///c:/Users/raffa/Desktop/Nuova%20cartella%20(3)/veyon/plugins/vncserver/CMakeLists.txt)
* Aggiunta l'inclusione della sottodirectory del server VNC `screencapturekit` quando `VEYON_BUILD_APPLE` è attivo:

```diff
 if(VEYON_BUILD_LINUX)
 	add_subdirectory(pipewire)
 endif()
+
+if(VEYON_BUILD_APPLE)
+	add_subdirectory(screencapturekit)
+endif()
```

### 2.4 [service/CMakeLists.txt](file:///c:/Users/raffa/Desktop/Nuova%20cartella%20(3)/veyon/service/CMakeLists.txt)
* Aggiunta la regola di configurazione e installazione del file plist per il LaunchDaemon di sistema in `/Library/LaunchDaemons`:

```diff
+if(VEYON_BUILD_APPLE)
+	configure_file(${CMAKE_SOURCE_DIR}/plugins/platform/macos/io.veyon.service.plist.in ${CMAKE_CURRENT_BINARY_DIR}/io.veyon.service.plist @ONLY)
+	if(NOT LAUNCHD_DAEMON_INSTALL_DIR)
+		set(LAUNCHD_DAEMON_INSTALL_DIR /Library/LaunchDaemons)
+	endif()
+	install(FILES ${CMAKE_CURRENT_BINARY_DIR}/io.veyon.service.plist DESTINATION ${LAUNCHD_DAEMON_INSTALL_DIR})
+endif()
```

### 2.5 [core/CMakeLists.txt](file:///c:/Users/raffa/Desktop/Nuova%20cartella%20(3)/veyon/core/CMakeLists.txt)
* Configurazione delle destinazioni di installazione complete (`LIBRARY`, `RUNTIME`, `ARCHIVE`) per la libreria condivisa `veyon-core` su sistemi Unix/macOS:

```diff
-		install(TARGETS veyon-core LIBRARY DESTINATION ${VEYON_LIB_DIR})
+		install(TARGETS veyon-core
+			LIBRARY DESTINATION ${VEYON_LIB_DIR}
+			RUNTIME DESTINATION ${VEYON_LIB_DIR}
+			ARCHIVE DESTINATION ${VEYON_LIB_DIR})
```

### 2.6 [cmake/CPackDefinitions.cmake](file:///c:/Users/raffa/Desktop/Nuova%20cartella%20(3)/veyon/cmake/CPackDefinitions.cmake)
* Sostituito il generatore deprecato `PackageMaker` con i moderni generatori standard di macOS: `DragNDrop` (per generare immagini disco `.dmg`) e `productbuild` (per installatori `.pkg`):

```diff
-elseif( ${CMAKE_SYSTEM_NAME} MATCHES "Darwin")   # TODO
-	set(CPACK_GENERATOR "PackageMake")
+elseif( ${CMAKE_SYSTEM_NAME} MATCHES "Darwin" OR APPLE)
+	set(CPACK_GENERATOR "DragNDrop;productbuild")
+	set(CPACK_DMG_VOLUME_NAME "Veyon")
+	set(CPACK_PACKAGE_FILE_NAME "veyon-${CPACK_PACKAGE_VERSION}-macos")
+	set(CPACK_SOURCE_GENERATOR "TGZ")
```

---

## 3. Nuovi Moduli e File Creati

### 3.1 Plugin di Piattaforma macOS (`plugins/platform/macos/`)

| File | Scopo |
|---|---|
| `CMakeLists.txt` | Configurazione di compilazione CMake; collega i framework nativi (Cocoa, IOKit, CoreGraphics, Security, SystemConfiguration, OpenDirectory, ServiceManagement) e attiva ARC (`-fobjc-arc`). |
| `MacPlatformPlugin.h` / `.mm` | Classe principale del plugin (IID `"io.veyon.Veyon.Plugins.MacPlatform"`). Gestione handler segnali `SIGSEGV`/`SIGBUS` con estrazione backtrace leggibile. |
| `MacPlatformConfiguration.h` | Proprietà di configurazione proxy per macOS (controllo prevent sleep, prevent display sleep, servizio PAM). |
| `MacCoreFunctions.h` / `.mm` | Implementazione `PlatformCoreFunctions`: riavvio/spegnimento tramite AppleScript, elevazione con `osascript with administrator privileges`, stato salvaschermo e logging nativo. |
| `MacFilesystemFunctions.h` / `.cpp` | Implementazione `PlatformFilesystemFunctions`: gestione percorsi standard macOS (`/Library/Application Support/Veyon`), permessi POSIX e ricerca processi con lock su file tramite `lsof`. |
| `MacInputDeviceFunctions.h` / `.mm` | Implementazione `PlatformInputDeviceFunctions`: disabilitazione e riabilitazione di tastiera e mouse locali tramite `CGEventTap`. |
| `MacKeyboardShortcutTrapper.h` / `.mm` | Intercettazione e blocco scorciatoie di sistema critiche (Cmd+Tab, Cmd+Space, Cmd+Opt+Esc) durante il blocco schermo. |
| `MacNetworkFunctions.h` / `.cpp` | Implementazione `PlatformNetworkFunctions`: ping BSD, keepalive socket macOS (`TCP_KEEPALIVE`), rilevamento interfaccia di routing di default e configurazione firewall con `socketfilterfw`. |
| `MacServiceFunctions.h` / `.mm` | Implementazione `PlatformServiceFunctions`: interazione con `launchctl` (bootstrap, bootout, load, unload), installazione/disinstallazione LaunchDaemon. |
| `MacServiceCore.h` / `.mm` | Cuore del servizio daemon: monitora gli accessi utente, gestisce il processo `veyon-server` per ciascuna sessione (anche schermata di login `loginwindow`) e garantisce il riavvio automatico post-crash. |
| `MacSessionFunctions.h` / `.mm` | Implementazione `PlatformSessionFunctions`: estrazione SecuritySession ID, uptime della sessione di console via `utmpx` e callback di notifica cambio utente via `SCDynamicStore`. |
| `MacUserFunctions.h` / `.mm` | Implementazione `PlatformUserFunctions`: interrogazione di utenti e gruppi locali e di dominio tramite il framework nativo `OpenDirectory` (`ODSession`, `ODQuery`) e autenticazione credenziali. |
| `MacPowerManager.h` / `.mm` | Gestione asserzioni energetiche `IOPMAssertion` per prevenire lo sleep del sistema e dell'interfaccia di rete durante le sessioni di monitoraggio. |
| `io.veyon.service.plist.in` | Template di configurazione del LaunchDaemon di sistema eseguito come root all'avvio del computer. |
| `veyon-screen-recording.mobileconfig.in` | Template del profilo MDM per l'approvazione automatica (silente) dei permessi Privacy TCC Screen Recording e Accessibility. |
| `macos.qrc` | File di risorse Qt che incorpora i template plist. |

### 3.2 Plugin Server VNC ScreenCaptureKit (`plugins/vncserver/screencapturekit/`)

| File | Scopo |
|---|---|
| `CMakeLists.txt` | Build configuration del plugin `screencapturekit-vnc-server` con collegamento a `LibVNCServer`, `ScreenCaptureKit`, `CoreMedia`, `CoreVideo`, `IOSurface`. |
| `ScreenCaptureKitConfiguration.h` | Proprietà configurabili del server VNC (framerate obiettivo, visibilità cursore). |
| `ScreenCaptureKitVncServer.h` / `.mm` | Implementazione di `VncServerPluginInterface`: inizializza l'istanza `rfbScreenInfoPtr`, accetta connessioni VNC, autenticazione con password e conversione eventi tastiera/mouse remoti in eventi di sistema macOS (`CGEventPost`). |
| `MacScreenCapture.h` / `.mm` | Motore di cattura ibrido: su macOS 12.3+ usa l'API moderna ad alte prestazioni `ScreenCaptureKit` (`SCStream`), con fallback trasparente a `CGDisplayStream` per la schermata di login o sistemi macOS precedenti. |

---

## 4. Architettura Tecnica macOS

### 4.1 Cattura Schermo e Permessi TCC (Privacy)
macOS impone la protezione TCC (**Transparency, Consent, and Control**) sull'accesso alla registrazione schermo.
* **Nei laboratori gestiti (Enterprise / Scuole)**: La profilazione MDM tramite file `.mobileconfig` pre-autorizza l'identificativo binario di `veyon-server` e `veyon-service` evitando qualsiasi popup agli studenti.
* **Nei computer standalone**: Viene utilizzato `CGPreflightScreenCaptureAccess()` per rilevare lo stato e `CGRequestScreenCaptureAccess()` per richiedere l'autorizzazione guidando l'utente in *Impostazioni di Sistema > Privacy e Sicurezza > Registrazione Schermo*.
* **Finestra di Login (`loginwindow`)**: Quando nessun utente è autenticato, il demone root effettua la cattura dello schermo principale tramite `CGDisplayStreamCreateWithDispatchQueue` associato a `CGMainDisplayID()`.

### 4.2 Servizio di Sistema LaunchDaemon (`launchd`)
* Il servizio `veyon-service` viene registrato come **LaunchDaemon** in `/Library/LaunchDaemons/io.veyon.service.plist`.
* Si avvia all'avvio della macchina (`RunAtLoad = true`) prima del login di qualsiasi utente.
* Viene supervisionato da `launchd`: in caso di terminazione imprevista o crash, `launchd` provvede a riavviarlo automaticamente (`KeepAlive = true` con `ThrottleInterval = 5`).

### 4.3 Gestione Energetica e Prevenzione Sleep (IOKit)
Per evitare che gli iMac o i MacBook chiusi o inattivi vadano in sospensione interrompendo il monitoraggio del docente:
* Viene creata un'asserzione `kIOPMAssertPreventUserIdleSystemSleep` che impedisce lo standby da inattività.
* Viene creata un'asserzione `kIOPMAssertNetworkClientActive` che mantiene la scheda di rete (Wi-Fi o Ethernet) alimentata e responsiva.
* Viene registrata una callback con `IORegisterForSystemPower` per gestire in modo pulito le transizioni energetiche del kernel.

### 4.4 Monitoraggio Sessioni e Fast User Switching (SCDynamicStore)
A differenza di Linux che impiega D-Bus (`systemd-logind`), macOS gestisce il cambio utente rapido tramite il database di stato `SystemConfiguration`:
* Viene installata una sorgente nel RunLoop associata alla chiave `State:/Users/ConsoleUser`.
* Alla disconnessione o cambio utente rapido, `MacServiceCore` riceve la notifica immediata e commuta il processo `veyon-server` dalla sessione precedente alla nuova sessione attiva.

### 4.5 Gestione Utenti e Gruppi (OpenDirectory)
L'interrogazione degli utenti e dei gruppi (fondamentale per il controllo degli accessi di Veyon Master) utilizza l'API nativa `OpenDirectory.framework`. Questa supporta sia gli utenti locali di macOS che gli utenti gestiti tramite domini Active Directory o OpenDirectory di rete.

---

## 5. Guida alla Compilazione (Build) e Installazione su macOS

Questa guida illustra tutti i passaggi per compilare Veyon su un Mac (Intel o Apple Silicon M1/M2/M3/M4) con **macOS 12 Monterey, macOS 13 Ventura, macOS 14 Sonoma o macOS 15 Sequoia**.

### 5.1 Prerequisiti
È necessario avere installato:
1. **Xcode Command Line Tools** (o Xcode completo):
   ```bash
   xcode-select --install
   ```
2. **Homebrew** (il gestore di pacchetti per macOS):
   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```

### 5.2 Installazione Dipendenze con Homebrew
Installare le librerie richieste da Veyon:
```bash
# Strumenti di build
brew install cmake ninja pkg-config

# Qt (supportati sia Qt 5 che Qt 6)
brew install qt@6

# Dipendenze crittografiche e VNC
brew install openssl@3 qca libvncserver
```

> [!TIP]
> Aggiungere Qt 6 al PATH temporaneo della shell corrente:
> ```bash
> export PATH="/opt/homebrew/opt/qt@6/bin:$PATH"
> export CMAKE_PREFIX_PATH="/opt/homebrew/opt/qt@6;/opt/homebrew/opt/openssl@3;/opt/homebrew/opt/qca"
> ```
> *(Su Mac Intel il percorso è `/usr/local/opt/...` al posto di `/opt/homebrew/opt/...`)*

### 5.3 Configurazione CMake
Dalla cartella principale del codice sorgente di Veyon:

```bash
mkdir build && cd build

cmake .. \
  -G "Ninja" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/usr/local \
  -DCMAKE_PREFIX_PATH="/opt/homebrew/opt/qt@6;/opt/homebrew/opt/openssl@3;/opt/homebrew/opt/qca" \
  -DWITH_QT6=ON \
  -DWITH_PCH=OFF
```

Note sulle opzioni CMake:
* `-G "Ninja"`: Utilizza il generatore Ninja per una compilazione rapida e parallela.
* `-DCMAKE_INSTALL_PREFIX=/usr/local`: Percorso di installazione standard per strumenti a riga di comando e demoni su macOS.
* `-DWITH_QT6=ON`: Utilizza Qt 6 (se si utilizza Qt 5 impostare `-DWITH_QT6=OFF`).

### 5.4 Compilazione
Avviare la compilazione sfruttando tutti i core della CPU:
```bash
cmake --build . -j$(sysctl -n hw.ncpu)
```

Al termine della compilazione troverai:
* La libreria principale: `core/libveyon-core.dylib`
* Gli eseguibili: `server/veyon-server`, `service/veyon-service`, `master/veyon-master`, `configurator/veyon-configurator`, `cli/veyon-cli`
* I plugin compilati: `plugins/platform/macos/macos-platform.dylib` e `plugins/vncserver/screencapturekit/screencapturekit-vnc-server.dylib`

### 5.5 Installazione nel Sistema
Per installare Veyon e registrare i file di servizio nel sistema operativo:
```bash
sudo cmake --install .
```

Questo comando installerà:
1. Gli eseguibili in `/usr/local/bin/`
2. Le librerie e i plugin in `/usr/local/lib/veyon/`
3. I file di traduzione e supporto in `/usr/local/share/veyon/`
4. Il file LaunchDaemon del servizio in `/Library/LaunchDaemons/io.veyon.service.plist`

### 5.6 Creazione Pacchetti di Distribuzione (DMG / PKG)
Per generare l'installer per la distribuzione su altri Mac senza ricompilare:

```bash
cpack
```

Questo genererà nella cartella `build/`:
* Un'immagine disco montabile nativa **`.dmg`** (con trascinamento in Applicazioni).
* Un file installer di sistema **`.pkg`** (installabile direttamente anche tramite MDM come Jamf, Mosyle o Kandji).

### 5.7 Configurazione Post-Installazione e Permessi

#### 1. Avvio del Servizio LaunchDaemon
Per avviare il servizio di background in esecuzione automatica:
```bash
sudo launchctl bootstrap system /Library/LaunchDaemons/io.veyon.service.plist
```
*(Oppure con la sintassi legacy: `sudo launchctl load -w /Library/LaunchDaemons/io.veyon.service.plist`)*

#### 2. Configurazione di Veyon
Avviare il configuratore per impostare le chiavi di autenticazione o il metodo di accesso:
```bash
sudo /usr/local/bin/veyon-configurator
```

#### 3. Distribuzione Permessi TCC in Ambienti Scolastici/Aziendali (MDM)
In un parco macchine gestito, distribuire il profilo MDM compilato dal template [veyon-screen-recording.mobileconfig.in](file:///c:/Users/raffa/Desktop/Nuova%20cartella%20(3)/veyon/plugins/platform/macos/veyon-screen-recording.mobileconfig.in) tramite il proprio server MDM. Ciò eviterà qualsiasi richiesta interattiva di registrazione schermo o accessibilità agli studenti.
