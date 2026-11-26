# FlipdexOS — FlipEx Monitor

Client Linux ARM64 conçu en priorité pour le **Lenovo Chromebook Duet MediaTek Helio P60T sous postmarketOS + Plasma Desktop**. Il ouvre le bureau virtuel de **FlipEx** dans une fenêtre et le pilote avec le pavé tactile et le clavier du Chromebook. Debian/Ubuntu restent des cibles secondaires.

> **État : étape 4 en cours.** Le client Linux et le Flatpak ARM64 sont intégrés au dépôt et passent par une compilation CI dédiée. Le fonctionnement réel doit encore être confirmé sur le Lenovo Duet et le Samsung Z Flip 6. L'APK Android de FlipEx n'est pas généré par ce dépôt : son code reste externe et sans licence déclarée.

## Ce que fait FlipEx Monitor

1. Le Chromebook se connecte au Z Flip 6 par USB et ADB.
2. Le lanceur démarre l'application Android FlipEx.
3. scrcpy ouvre un **nouvel écran virtuel** Android dans une fenêtre Linux : ce n'est pas le miroir de l'écran principal du téléphone.
4. Le pavé tactile et le clavier du Chromebook contrôlent le bureau affiché.
5. Le téléphone conserve son écran principal et peut rester utilisable indépendamment.

Le contrôle est actif : **ne pas ajouter `--no-control`**, car cette option désactive les entrées souris et clavier.

## Commande depuis le menu du Chromebook

Après installation, ouvre **FlipEx Monitor — Connexion** depuis le menu des applications. Le lanceur choisit automatiquement l'unique téléphone ADB autorisé, détecte la résolution du Chromebook et démarre FlipEx puis le bureau virtuel. Le lanceur de menu ne demande pas d'ouvrir un terminal.

En cas d'erreur, une notification du bureau est affichée lorsque `notify-send` ou `kdialog` est disponible. Une notification indique également que le téléphone est connecté et que le bureau s'ouvre.

**Première autorisation USB :** Android impose d'accepter l'empreinte de débogage USB sur le Z Flip 6. Branche le téléphone, déverrouille-le et accepte la demande Android (tu peux cocher « Toujours autoriser depuis cet ordinateur »). FlipdexOS ne peut pas accepter cette autorisation à la place de l'utilisateur. Le débogage USB doit rester activé.

## Souris et clavier

### Souris — mode par défaut `sdk`

Le mode par défaut transmet les événements de souris à Android par son API, avec des coordonnées absolues. Le curseur reste géré par le Chromebook : il n'est pas capturé et il n'est pas nécessaire d'appuyer sur Alt pour le récupérer.

Les clics secondaires sont explicitement transmis à Android au lieu d'être convertis en raccourcis Retour / Accueil / notifications. Le comportement précis du clic droit, du glisser-déposer et de la molette dépend aussi de la façon dont One UI et les applications Android gèrent les événements de souris.

Pour utiliser une véritable souris HID Android à la place :

```bash
flipex-monitor --mouse uhid
```

Le mode `uhid` simule une souris physique. scrcpy capture alors le pointeur du Chromebook ; **Alt gauche** libère ou reprend la capture. C'est pourquoi ce mode n'est pas le réglage par défaut.

### Clavier — mode par défaut `uhid`

Le clavier du Chromebook est transmis comme un clavier physique Android. Configure une seule fois le clavier physique du téléphone en Français (AZERTY) dans les paramètres Android.

Pour tester l'autre mode clavier :

```bash
flipex-monitor --keyboard sdk
```

## Écran virtuel et écran overlay facultatif

Le réglage par défaut est :

- `--display-mode virtual` : demande directement un nouvel écran virtuel à scrcpy. C'est le chemin normal ; il évite le détour par un écran overlay de test.
- `--display-mode overlay` : utilise à la place un écran secondaire overlay créé dans les paramètres Android. C'est une solution de repli à essayer uniquement si l'écran virtuel standard ne convient pas sur un appareil donné.

L'overlay est facultatif et n'est **pas choisi automatiquement** sur Android 17. Quand le mode overlay est utilisé, le script mémorise la valeur précédente de `overlay_display_devices` et la restaure à la fermeture de scrcpy.

## Résolution et netteté

Le profil par défaut `--display auto` détecte le mode d'affichage actif du Chromebook et aligne l'écran virtuel sur la surface réellement rendue par FlipEx. Le code Android FlipEx actuel limite le petit côté de sa surface DeX à **1080 pixels**. Demander 1440p ou 4K à scrcpy n'ajoute aucun détail lorsque FlipEx dessine toujours une image 1080p : cela agrandit seulement cette image et peut rendre le texte et les contours flous.

Exemples :

- Lenovo Duet en 1920 × 1200 (16:10) : **1728 × 1080**.
- Écran 1920 × 1080 (16:9) : **1920 × 1080**.
- Écran 3840 × 2160 (4K) : **1920 × 1080**, sans agrandissement artificiel.

Le profil reprend aussi la densité DeX Samsung lorsqu'elle est disponible, utilise H.264, 20 Mbit/s, 30 FPS et un tampon vidéo minimal. Lorsque scrcpy le permet, il désactive la réduction automatique de résolution après une erreur d'encodeur pour éviter une baisse silencieuse de définition. La résolution Android reste **fixe pendant le redimensionnement de la fenêtre**, afin d'éviter que la surface DeX baisse automatiquement de définition. L'option `--flex-display` est disponible en opt-in pour adapter dynamiquement la surface à la taille de la fenêtre, au prix d'une définition qui peut baisser quand la fenêtre est réduite.

Pour forcer manuellement la résolution :

```bash
flipex-monitor --display 1728x1080/160
flipex-monitor --display 1920x1080/160
flipex-monitor --flex-display
```

Pour une vraie sortie DeX 1440p ou 4K, il faudra d'abord modifier FlipEx pour que son écran virtuel interne soit rendu au-delà de sa limite actuelle de 1080 pixels. Augmenter uniquement la capture scrcpy ne peut pas recréer les détails que l'application Android n'a pas dessinés.

## Environnement pris en charge

Cible principale : Lenovo Chromebook Duet, SoC MediaTek Helio P60T, architecture `aarch64`, postmarketOS (base Alpine Linux) et Plasma Desktop. La détection de résolution privilégie `kscreen-doctor`, le gestionnaire d'écrans KDE, puis essaie `wlr-randr` et `xrandr`. Le profil automatique ne dépend donc pas d'X11 pour fonctionner dans une session Plasma Wayland.

Le script de compilation scrcpy utilise `apk` sur postmarketOS/Alpine, avec `doas` ou `sudo` selon l'outil disponible. Il garde `apt-get` uniquement pour les systèmes Debian/Ubuntu.

## Prérequis

Sur le Z Flip 6 :

1. Installer et configurer l'application Android [FlipEx](https://github.com/Vedjamkar/flipex).
2. Installer Shizuku depuis une source officielle, démarrer son serveur via ADB et vérifier que FlipEx est autorisé dans Shizuku.
3. Activer les options développeur et le débogage USB.
4. Déverrouiller le téléphone et autoriser l'ordinateur ADB.

Sur le Chromebook sous postmarketOS + Plasma :

```bash
bash scripts/install-scrcpy-latest.sh
bash scripts/install-system.sh --user
```

Le premier script utilise `apk` pour installer les dépendances Alpine, récupère le serveur officiel scrcpy 5.0.1, vérifie sa somme SHA-256, compile le client sur l'architecture locale ARM64 et l'installe dans `/usr/local/bin`. Il sait aussi utiliser `apt-get` sur Debian/Ubuntu, mais ce n'est pas la procédure de référence du Lenovo Duet.

Le second script installe le lanceur dans `~/.local/bin` et le raccourci dans `~/.local/share/applications`, sans demander les droits root. Plasma utilise un chemin absolu vers le lanceur. Une installation système reste possible avec `bash scripts/install-system.sh --system` et `doas` ou `sudo`.

La compilation scrcpy 5.0.1 exige SDL 3.2 ou plus récent, FFmpeg 6 ou plus récent et libusb. Sur une base postmarketOS trop ancienne pour fournir `sdl3-dev`, le script s'arrête sans mélanger des dépôts Alpine edge à la distribution : il faut d'abord mettre à jour postmarketOS vers une base disposant de SDL3. N'ajoute pas un dépôt edge manuellement à une base stable.

## Version Flatpak pour le Chromebook ARM64

Le dépôt fournit aussi un paquet Flatpak **distinct de l'APK Android**. Il vise le Lenovo Duet sous postmarketOS + Plasma, architecture `aarch64`.

La méthode conserve ADB et scrcpy sur le système hôte : ils doivent accéder à l'USB et au compositeur graphique avec les permissions de postmarketOS. Le Flatpak utilise un petit pont `flatpak-spawn --host` pour appeler uniquement les commandes attendues (`adb`, `scrcpy`, les outils de résolution Plasma et les notifications). Il ne demande ni accès global au dossier personnel, ni `--device=all`, ni réseau dans le bac à sable.

**Attention sécurité :** le droit D-Bus `org.freedesktop.Flatpak` nécessaire au lancement de commandes hôte est puissant. Ce Flatpak est prévu pour une installation locale de confiance sur ton Chromebook, pas pour une publication Flathub sans remplacer ce pont par une intégration plus restrictive.

Depuis la racine du dépôt :

```bash
bash scripts/install-scrcpy-latest.sh
bash scripts/build-flatpak.sh --install
```

Le premier script installe ADB et compile scrcpy pour l'architecture du Chromebook. Le second construit le bundle Flatpak ARM64, vérifie son SHA-256 puis l'installe pour l'utilisateur. Le lanceur **FlipdexOS — FlipEx Monitor** apparaît dans le menu Plasma et ouvre un terminal pour afficher les diagnostics. La construction seule, sans installation, se fait avec `bash scripts/build-flatpak.sh`.

Pour démarrer ou diagnostiquer depuis le terminal :

```bash
flatpak run io.github.yoyote84.flipdexos --check
flatpak run io.github.yoyote84.flipdexos --list
flatpak run io.github.yoyote84.flipdexos
```

Le bundle utilise le runtime Freedesktop 26.08 et est construit sur un runner ARM64 natif dans GitHub Actions. Il ne contient pas de binaire scrcpy compilé pour une autre machine ; il s'appuie sur la version hôte installée ci-dessus.

Le Chromebook doit disposer d'une session graphique Plasma (Wayland ou X11). Le câble USB-C transporte ici ADB et le flux vidéo compressé ; il ne transforme pas le Chromebook en moniteur HDMI natif.

## Installation

Depuis la racine du dépôt :

```bash
chmod +x scripts/*.sh
bash scripts/flipex-monitor.sh --check
bash scripts/flipex-monitor.sh --list
bash scripts/install-system.sh --user
```

Ouvre ensuite **FlipEx Monitor — Connexion** dans le menu Plasma. Pour lancer depuis le terminal, utilise `$HOME/.local/bin/flipex-monitor` ou ajoute `$HOME/.local/bin` à ton `PATH`.

## Options pratiques

```bash
flipex-monitor --help
flipex-monitor --check
flipex-monitor --list
flipex-monitor --display 1600x900/160 --fps 30 --bit-rate 6M
flipex-monitor --mouse uhid
flipex-monitor --display-mode overlay
flipex-monitor --restore
```

Si plusieurs appareils ADB sont connectés :

```bash
flipex-monitor --serial NUMERO_ADB
```

Chaque session sauvegarde les valeurs initiales des trois réglages globaux du mode bureau (et, en mode overlay, l'ancien paramètre overlay) dans `$HOME/.local/state/flipdex-monitor/` avec des permissions privées. À la fermeture normale de scrcpy, FlipdexOS restaure automatiquement ces valeurs. Si le Chromebook ou le processus est interrompu brutalement, exécute `flipex-monitor --restore` : la commande restaure les valeurs réellement sauvegardées, sans forcer arbitrairement les réglages à `0`. Elle ne désinstalle pas FlipEx. Pour restaurer les réglages propres à FlipEx, utiliser **Restore stock settings** dans l'application Android.

## Android 17 / One UI 9

Le client Linux prend en charge Android API 37 avec scrcpy 5.0.1 ou ultérieur. Il détecte aussi le `targetSdk` de l'APK FlipEx. Si l'APK cible encore API 36, il l'indique clairement : l'avertissement de compatibilité Android appartient à l'application FlipEx et doit être corrigé dans son dépôt Android (mise à jour du manifeste, compilation SDK et validation des fenêtres multi-écrans). FlipdexOS ne modifie pas l'APK installée sur le téléphone.

### APK Android destiné au Galaxy Z Flip6

L'APK est bien la partie destinée au **Samsung Galaxy Z Flip6** ; le Flatpak est uniquement destiné au Chromebook. FlipdexOS ne contient toutefois pas le module Android de FlipEx. Le dépôt Android externe publie actuellement une source `0.3.4` avec `compileSdk 36` et `targetSdk 36`, mais aucune licence n'est déclarée dans les métadonnées GitHub et aucun fichier `LICENSE` n'est présent. Sa dernière release publiée est encore `v0.3.0`.

En conséquence, ce dépôt ne reconditionne pas son code et ne prétend pas fournir un nouvel APK. Pour Android 17, la documentation officielle indique `compileSdk 37`; l'adoption de `targetSdk 37` doit être faite après les tests de comportement correspondants. L'APK final devra être construit et signé avec une source que nous sommes autorisés à modifier et redistribuer, puis testé sur le Z Flip6.

Voir le [rapport de compilation de l'étape 4/5](docs/FLIPDEXOS_STEP_4.md).

### Diagnostic Android / Shizuku / FlipEx

Pour vérifier l'état réel du téléphone avant un test DeX, connecte le Z Flip 6 en USB, autorise ADB, puis exécute :

```bash
bash scripts/diagnose-flipex-android.sh
```

Pour conserver le résultat :

```bash
bash scripts/diagnose-flipex-android.sh --output ~/flipex-android-report.txt
```

Ce diagnostic est en lecture seule. Il détecte Android/API, One UI, la présence de Shizuku et de FlipEx, le target SDK de l'APK installé et la présence éventuelle du processus serveur Shizuku dans `ps -A`. La présence du processus ne garantit pas le Binder : il faut aussi vérifier que Shizuku affiche « en cours d'exécution » et que FlipEx est autorisé. Le lanceur refait ce précontrôle avant de modifier les réglages Android. Voir le [rapport de compatibilité de l'étape 2/5](docs/FLIPEX_ANDROID_COMPATIBILITY_STEP_2.md).

## Tests et développement

Depuis la racine du dépôt :

```bash
bash -n scripts/flipex-monitor.sh
bash -n scripts/install-system.sh
bash -n scripts/install-scrcpy-latest.sh
bash tests/fake-tools.sh
bash tests/flipex-android-preflight.sh
bash tests/flatpak-packaging.sh
```

Les tests simulés vérifient KScreen/Plasma, les profils 16:9/16:10/4K, la résolution fixe et son option adaptative, les modes de souris et clavier, la détection préalable de Shizuku, la sauvegarde/restauration des réglages Android et la récupération du paramètre overlay. GitHub Actions exécute aussi les tests dans Alpine 3.24 et construit un bundle Flatpak sur ARM64 natif. Ces contrôles ne remplacent pas un essai sur le Lenovo Duet et le Z Flip 6 réels.

## Références techniques

- [Projet FlipEx Android et client de bureau](https://github.com/Vedjamkar/flipex)
- [Documentation Flatpak — manifeste et compilation](https://docs.flatpak.org/en/latest/manifests.html)
- [Documentation Flatpak — permissions du bac à sable](https://docs.flatpak.org/en/latest/sandbox-permissions.html)
- [Documentation scrcpy — souris](https://github.com/Genymobile/scrcpy/blob/master/doc/mouse.md)
- [Documentation scrcpy — clavier](https://github.com/Genymobile/scrcpy/blob/master/doc/keyboard.md)
- [Options scrcpy](https://github.com/Genymobile/scrcpy/blob/master/app/scrcpy.1)

FlipdexOS Monitor est un projet indépendant et n'est ni développé, ni approuvé par Samsung ou par les auteurs de FlipEx.
