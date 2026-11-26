# Validation matérielle — Lenovo Duet postmarketOS + Galaxy Z Flip 6 One UI 9

Cible de cette procédure : **Lenovo Chromebook Duet, MediaTek Helio P60T, ARM64/aarch64, postmarketOS avec Plasma Desktop**, et Galaxy Z Flip 6 sous One UI 9 / Android 17. Le bureau DeX reste affiché dans une fenêtre Linux; le téléphone conserve son écran principal.

## 1. Mettre à jour le dépôt

Depuis le répertoire FlipdexOS :

```bash
git pull --ff-only origin main
chmod +x scripts/*.sh
```

## 2. Installer scrcpy 5.0.1 pour postmarketOS / Alpine

L'installation principale passe par **apk**, et l'élévation utilise **doas** ou **sudo** selon ce qui est présent :

```bash
bash scripts/install-scrcpy-latest.sh
/usr/local/bin/scrcpy --version
adb version
uname -m
```

Le script installe les dépendances SDL3, FFmpeg, libusb et les outils de compilation, télécharge le serveur scrcpy officiel, vérifie sa somme SHA-256, compile le client pour l'architecture locale, puis l'installe dans `/usr/local/bin`.

La version officielle vérifiée au moment de cette mise à jour est scrcpy 5.0.1. Les versions plus anciennes sont rejetées par le lanceur, car le profil Android 17 repose sur les options de cette version.

**Attention :** scrcpy 5.0.1 nécessite SDL 3.2 ou plus récent et FFmpeg 6 ou plus récent. Si le dépôt postmarketOS de ton système ne fournit pas `sdl3-dev`, l'installateur s'arrête avec l'erreur d'APK. Ne mélange pas manuellement les dépôts Alpine edge à une base postmarketOS stable : il faut d'abord mettre à jour la base du système.

## 3. Installer le lanceur dans Plasma

Installation utilisateur, sans accès root :

```bash
bash scripts/install-system.sh --user
```

Cela place le lanceur dans `~/.local/bin/flipex-monitor` et crée le raccourci Plasma dans `~/.local/share/applications`. Le fichier de menu appelle le chemin complet et ne dépend pas du `PATH` du bureau. Ouvre **FlipEx Monitor — Connexion** depuis le menu Plasma.

Pour lancer depuis le terminal :

```bash
$HOME/.local/bin/flipex-monitor --check
```

L'option `--system` installe au contraire dans `/usr/local/bin` et utilise `doas` ou `sudo`.

## 4. Préparer le Z Flip 6

Sur le téléphone :

1. Active les Options pour les développeurs et le Débogage USB.
2. Branche le téléphone au Chromebook en USB-C.
3. Déverrouille-le et accepte l'empreinte RSA ADB.
4. Vérifie que FlipEx est installé et configuré avec Shizuku.
5. Dans Shizuku, démarre le serveur en mode ADB et vérifie que l'application affiche **en cours d'exécution**.
6. Dans Shizuku → Applications autorisées, vérifie que FlipEx est autorisé. Le processus visible par ADB est seulement un indice : seul FlipEx peut valider son Binder.
7. Dans FlipEx → Experimental → DeX window owner, privilégie **Shizuku** pour éviter la fenêtre d'accessibilité appelée **FlipEx DeX screen**.
8. Laisse **Test display on the phone** désactivé : ce n'est pas nécessaire au flux scrcpy.

Sur le Chromebook :

```bash
adb devices -l
adb shell getprop ro.build.version.sdk
adb shell dumpsys package dev.ved.flipdex | grep -E 'versionName|targetSdk'
adb shell ps -A | grep -E 'shizuku_server|libshizuku\.so' || true
bash scripts/diagnose-flipex-android.sh
```

Pour Android 17, le SDK attendu est 37. Le diagnostic est en lecture seule et ne prouve pas que le Binder Shizuku fonctionne dans FlipEx. Si FlipEx indique `targetSdk=36`, l'avertissement de compatibilité appartient à l'APK Android. FlipdexOS sait le détecter, mais ne peut pas reconstruire l'APK issue du dépôt Android externe.

## 5. Vérifier Plasma et lancer DeX avec une résolution nette

Dans Plasma, la résolution active est lue en priorité avec **KScreen** (`kscreen-doctor`). Le lanceur utilise ensuite `wlr-randr` ou `xrandr` si KScreen n'est pas disponible. Il ne dépend donc pas de `xrandr` dans une session Plasma Wayland.

Vérifie l'environnement :

```bash
echo "$XDG_SESSION_TYPE / $XDG_CURRENT_DESKTOP"
kscreen-doctor -o
```

Puis démarre :

```bash
bash scripts/flipex-monitor.sh --check
bash scripts/flipex-monitor.sh --list
bash scripts/flipex-monitor.sh
```

Le profil `auto` détecte la définition de l'écran et l'aligne sur la surface DeX réellement rendue par FlipEx. Le petit côté est plafonné à 1080 pixels par la logique actuelle de FlipEx :

| Écran du Chromebook | Surface virtuelle DeX |
|---|---:|
| 1920 × 1200 (16:10) | 1728 × 1080 |
| 1920 × 1080 (16:9) | 1920 × 1080 |
| 3840 × 2160 (4K) | 1920 × 1080 |

Réglages par défaut : H.264, 20 Mbit/s, 30 FPS, tampon vidéo minimal et refus de réduction automatique de résolution en cas d'erreur d'encodeur. La résolution Android reste fixe pendant le redimensionnement de la fenêtre. L'option `--flex-display` adapte la surface à la fenêtre; évite-la pendant le test de netteté, car réduire la fenêtre peut aussi réduire la définition. Un flux scrcpy 4K au-dessus d'une source DeX 1080p ne rendrait pas le texte plus net.

Pour une première comparaison manuelle :

```bash
flipex-monitor --display 1728x1080/160
flipex-monitor --display 1920x1080/160
```

Pour juger la netteté, compare à la taille native de la fenêtre. Dans Plasma, utilise une mise à l'échelle d'écran de 100 % pendant ce test ; une mise à l'échelle fractionnaire ou l'agrandissement de la fenêtre peut adoucir les caractères.

La vraie définition 1440p/4K nécessite de modifier la surface virtuelle dans FlipEx Android lui-même. Augmenter uniquement la capture scrcpy ne suffit pas.

## 6. Tester souris et clavier

La souris par défaut est en mode `sdk` : le curseur reste libre dans Plasma, tandis que les clics sont transmis à Android. Teste clic gauche, clic droit, molette, glisser-déposer et déplacement/redimensionnement de fenêtres DeX.

Si certaines fenêtres ignorent les événements SDK, compare le mode HID :

```bash
flipex-monitor --mouse uhid
```

En mode `uhid`, le pointeur est capturé. **Alt gauche** le libère et le reprend. Le clavier est transmis en mode HID ; configure la disposition du clavier physique Android en Français (AZERTY).

## 7. Rapport de diagnostic

Ferme scrcpy pour arrêter le flux : FlipdexOS restaure automatiquement les réglages globaux à leurs valeurs initiales. En cas d'arrêt brutal, exécute `flipex-monitor --restore` pour rétablir la sauvegarde. Ne remplace pas cette commande par des valeurs forcées à zéro. Si un problème persiste, exécute :

```bash
uname -a
cat /etc/os-release
echo "session=$XDG_SESSION_TYPE desktop=$XDG_CURRENT_DESKTOP"
kscreen-doctor -o 2>&1 || true
wlr-randr 2>&1 || true
xrandr --current 2>&1 || true
adb devices -l
adb shell getprop ro.build.version.sdk
adb shell dumpsys package dev.ved.flipdex | grep -E 'versionName|targetSdk'
/usr/local/bin/scrcpy --version
bash scripts/flipex-monitor.sh --check
```

Masque le numéro de série ADB avant de partager la sortie.

**Limites vérifiées du projet :** les tests automatisés sont simulés et lancés dans GitHub Actions, y compris sous Alpine. Ils ne prouvent pas encore le fonctionnement matériel sur le Chromebook, ni la disponibilité d'un décodage vidéo accéléré pour le pilote graphique du Helio P60T. Le premier essai réel permettra de mesurer la fluidité et la netteté de bout en bout.
