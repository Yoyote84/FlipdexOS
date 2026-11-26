# Validation matérielle — Lenovo Duet postmarketOS + Galaxy Z Flip6

Cible : **Lenovo Chromebook Duet, MediaTek Helio P60T, ARM64/aarch64, postmarketOS + Plasma Desktop**, et **Samsung Galaxy Z Flip6 sous One UI 9 / Android 17**.

Le bureau Android est exécuté dans un écran virtuel scrcpy et affiché dans une fenêtre Plasma. L'écran principal du téléphone doit rester utilisable séparément.

## 1. Mettre à jour le dépôt

```bash
cd ~/FlipdexOS
git pull --ff-only origin main
chmod +x scripts/*.sh
```

## 2. Installer scrcpy sur postmarketOS

```bash
bash scripts/install-scrcpy-latest.sh
/usr/local/bin/scrcpy --version
adb version
uname -m
```

Le script utilise `apk`, installe SDL3/FFmpeg/libusb, récupère le serveur scrcpy officiel, vérifie sa somme SHA-256 puis compile le client sur l'architecture locale. Il utilise `doas` ou `sudo` pour l'installation.

scrcpy 5.0.1 ou plus récent est requis pour `--new-display` et `--start-app`. Ne mélange pas manuellement les dépôts Alpine edge à une base postmarketOS stable si SDL3 est absent.

## 3. Installer le lanceur Plasma

```bash
bash scripts/install-system.sh --user
```

Le menu Plasma ajoute **FlipdexOS — Connexion**. Le binaire CLI garde son ancien nom `flipex-monitor` pour préserver la compatibilité.

## 4. Préparer le Z Flip6

1. Installe l'APK `app-debug.apk` depuis l'artefact GitHub Actions `flipdexos-android-debug-apk`.
2. Active les Options pour les développeurs et le Débogage USB.
3. Branche le téléphone au Chromebook, déverrouille-le et accepte l'empreinte RSA ADB.
4. Installe et ouvre Shizuku depuis sa source officielle.
5. Démarre le serveur Shizuku en mode ADB ou via le débogage sans fil Android.
6. Ouvre FlipdexOS sur le téléphone, appuie sur **Vérifier et connecter Shizuku** et accepte la demande d'autorisation.
7. Le rapport doit indiquer Binder actif et l'UID du service (normalement 2000 avec Shizuku démarré par ADB).

Le panneau compagnon n'active aucun réglage système à son ouverture. Le client hôte sauvegarde puis configure les trois réglages requis et les restaure à la fermeture de scrcpy.

## 5. Vérifier l'appareil et le transport ADB

Sur le Chromebook :

```bash
adb devices -l
adb shell getprop ro.build.version.sdk
adb shell dumpsys package io.github.yoyote84.flipdexos | grep -E 'versionName|targetSdk'
adb shell ps -A | grep -E 'shizuku_server|libshizuku.so' || true
bash scripts/diagnose-flipex-android.sh
```

Le diagnostic hôte est en lecture seule. La présence du processus Shizuku n'est qu'un indice ; le test Binder/UserService doit être fait dans l'application FlipdexOS sur le téléphone.

## 6. Lancer le bureau secondaire

Vérifie KScreen et le bureau Plasma :

```bash
echo "$XDG_SESSION_TYPE / $XDG_CURRENT_DESKTOP"
kscreen-doctor -o
bash scripts/flipex-monitor.sh --check
bash scripts/flipex-monitor.sh --list
bash scripts/flipex-monitor.sh
```

scrcpy demande un nouvel écran virtuel et démarre le paquet `io.github.yoyote84.flipdexos` dessus. Comme `--start-app` prend un nom de paquet, `MainActivity` détecte le lancement sur un écran secondaire et redirige vers `DesktopActivity`. Le panneau compagnon reste la page d'accueil de l'écran principal.

Le profil de résolution est volontairement conservateur : petit côté de 1080 pixels, 30 FPS et H.264. Exemples de profils manuels :

```bash
flipex-monitor --display 1728x1080/160
flipex-monitor --display 1920x1080/160
flipex-monitor --flex-display
```

Le réglage `--flex-display` réduit ou augmente dynamiquement la surface selon la fenêtre ; ne l'utilise pas pendant le premier test de netteté.

## 7. Vérifier les applications et les entrées

Dans le bureau secondaire :
- vérifier que la liste des applications installées apparaît ;
- rechercher une application par son nom ;
- lancer plusieurs applications et vérifier qu'elles s'ouvrent sur le même écran virtuel ;
- tester clic gauche, clic droit, molette, glisser-déposer et pavé tactile ;
- tester le clavier AZERTY.

Certaines applications Android peuvent refuser le lancement multi-écran ou rester limitées à une seule fenêtre. Le premier lanceur n'inclut pas encore un gestionnaire complet de fenêtres, un dock ni un menu des tâches.

## 8. Restaurer les réglages

À la fermeture normale de scrcpy, le client restaure les valeurs Android initiales. Si le Chromebook ou le processus s'arrête brutalement :

```bash
flipex-monitor --restore
```

Ne remplace pas cette commande par des valeurs forcées à zéro.

## 9. Rapport de test

```bash
uname -a
cat /etc/os-release
echo "session=$XDG_SESSION_TYPE desktop=$XDG_CURRENT_DESKTOP"
kscreen-doctor -o 2>&1 || true
wlr-randr 2>&1 || true
xrandr --current 2>&1 || true
adb devices -l
adb shell getprop ro.build.version.sdk
adb shell dumpsys package io.github.yoyote84.flipdexos | grep -E 'versionName|targetSdk'
/usr/local/bin/scrcpy --version
bash scripts/flipex-monitor.sh --check
```

Masque le numéro de série ADB avant de partager le rapport.

**Limite actuelle :** les tests simulés et les builds CI ne remplacent pas le test réel sur le Z Flip6 et le Chromebook. La fluidité, le rendu, l'ouverture des applications et la stabilité Shizuku doivent encore être confirmés matériellement.
