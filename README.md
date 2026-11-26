# FlipdexOS — FlipEx Monitor

Client Linux ARM64 conçu en priorité pour le **Lenovo Chromebook Duet MediaTek Helio P60T sous postmarketOS + Plasma Desktop**. Il ouvre le bureau virtuel de **FlipEx** dans une fenêtre et le pilote avec le pavé tactile et le clavier du Chromebook. Debian/Ubuntu restent des cibles secondaires.

> **État : version interactive en cours de validation matérielle.** Le lanceur, l'entrée souris/clavier, l'installation dans le menu et les tests simulés sont présents. Le fonctionnement exact avec le Lenovo Duet et le Samsung Z Flip 6 doit encore être confirmé sur les appareils réels. Aucun paquet ARM64 précompilé n'est publié.

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

Le profil reprend aussi la densité DeX Samsung lorsqu'elle est disponible, utilise H.264, 20 Mbit/s, 30 FPS et un tampon vidéo minimal. Lorsque scrcpy le permet, il désactive la réduction automatique de résolution après une erreur d'encodeur pour éviter une baisse silencieuse de définition.

Pour forcer manuellement la résolution :

```bash
flipex-monitor --display 1728x1080/160
flipex-monitor --display 1920x1080/160
```

Pour une vraie sortie DeX 1440p ou 4K, il faudra d'abord modifier FlipEx pour que son écran virtuel interne soit rendu au-delà de sa limite actuelle de 1080 pixels. Augmenter uniquement la capture scrcpy ne peut pas recréer les détails que l'application Android n'a pas dessinés.

## Environnement pris en charge

Cible principale : Lenovo Chromebook Duet, SoC MediaTek Helio P60T, architecture `aarch64`, postmarketOS (base Alpine Linux) et Plasma Desktop. La détection de résolution privilégie `kscreen-doctor`, le gestionnaire d'écrans KDE, puis essaie `wlr-randr` et `xrandr`. Le profil automatique ne dépend donc pas d'X11 pour fonctionner dans une session Plasma Wayland.

Le script de compilation scrcpy utilise `apk` sur postmarketOS/Alpine, avec `doas` ou `sudo` selon l'outil disponible. Il garde `apt-get` uniquement pour les systèmes Debian/Ubuntu.

## Prérequis

Sur le Z Flip 6 :

1. Installer et configurer l'application Android [FlipEx](https://github.com/Vedjamkar/flipex).
2. Activer les options développeur et le débogage USB.
3. Déverrouiller le téléphone et autoriser l'ordinateur ADB.

Sur le Chromebook sous postmarketOS + Plasma :

```bash
bash scripts/install-scrcpy-latest.sh
bash scripts/install-system.sh --user
```

Le premier script utilise `apk` pour installer les dépendances Alpine, récupère le serveur officiel scrcpy 5.0.1, vérifie sa somme SHA-256, compile le client sur l'architecture locale ARM64 et l'installe dans `/usr/local/bin`. Il sait aussi utiliser `apt-get` sur Debian/Ubuntu, mais ce n'est pas la procédure de référence du Lenovo Duet.

Le second script installe le lanceur dans `~/.local/bin` et le raccourci dans `~/.local/share/applications`, sans demander les droits root. Plasma utilise un chemin absolu vers le lanceur. Une installation système reste possible avec `bash scripts/install-system.sh --system` et `doas` ou `sudo`.

La compilation scrcpy 5.0.1 exige SDL 3.2 ou plus récent, FFmpeg 6 ou plus récent et libusb. Sur une base postmarketOS trop ancienne pour fournir `sdl3-dev`, le script s'arrête sans mélanger des dépôts Alpine edge à la distribution : il faut d'abord mettre à jour postmarketOS vers une base disposant de SDL3. N'ajoute pas un dépôt edge manuellement à une base stable.

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

La commande de restauration remet à zéro les trois réglages du mode bureau gérés par le lanceur et supprime le réglage overlay. Elle ne désinstalle pas FlipEx. Pour restaurer aussi les réglages propres à FlipEx, utiliser **Restore stock settings** dans l'application Android.

## Android 17 / One UI 9

Le client Linux prend en charge Android API 37 avec scrcpy 5.0.1 ou ultérieur. Il détecte aussi le `targetSdk` de l'APK FlipEx. Si l'APK cible encore API 36, il l'indique clairement : l'avertissement de compatibilité Android appartient à l'application FlipEx et doit être corrigé dans son dépôt Android (mise à jour du manifeste, compilation SDK et validation des fenêtres multi-écrans). FlipdexOS ne modifie pas l'APK installée sur le téléphone.

### Diagnostic Android / Shizuku / FlipEx

Pour vérifier l'état réel du téléphone avant un test DeX, connecte le Z Flip 6 en USB, autorise ADB, puis exécute :

```bash
bash scripts/diagnose-flipex-android.sh
```

Pour conserver le résultat :

```bash
bash scripts/diagnose-flipex-android.sh --output ~/flipex-android-report.txt
```

Ce diagnostic est en lecture seule. Il détecte Android/API, One UI, la présence de Shizuku et de FlipEx et le target SDK de l'APK installé. Il ne peut pas confirmer le Binder Shizuku de l'application : il faut aussi vérifier que Shizuku affiche « en cours d'exécution » et que FlipEx est autorisé. Voir le [rapport de compatibilité de l'étape 2/5](docs/FLIPEX_ANDROID_COMPATIBILITY_STEP_2.md).

## Tests et développement

Depuis la racine du dépôt :

```bash
bash -n scripts/flipex-monitor.sh
bash -n scripts/install-system.sh
bash -n scripts/install-scrcpy-latest.sh
bash tests/fake-tools.sh
```

Le test simulé vérifie KScreen/Plasma, les profils automatiques 16:9, 16:10 et 4K, le mode écran virtuel + souris SDK, le mode souris HID et la restauration de l'overlay. GitHub Actions exécute aussi les tests dans Alpine 3.24. Ces tests ne remplacent pas un essai sur le Lenovo Duet et le Z Flip 6 réels.

## Références techniques

- [Projet FlipEx Android et client de bureau](https://github.com/Vedjamkar/flipex)
- [Documentation scrcpy — souris](https://github.com/Genymobile/scrcpy/blob/master/doc/mouse.md)
- [Documentation scrcpy — clavier](https://github.com/Genymobile/scrcpy/blob/master/doc/keyboard.md)
- [Options scrcpy](https://github.com/Genymobile/scrcpy/blob/master/app/scrcpy.1)

FlipdexOS Monitor est un projet indépendant et n'est ni développé, ni approuvé par Samsung ou par les auteurs de FlipEx.
