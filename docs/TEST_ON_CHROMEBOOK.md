# Validation matérielle — Lenovo Duet + Galaxy Z Flip 6 (One UI 9)

Cette procédure valide le bureau DeX dans une fenêtre Linux, avec le pavé tactile et le clavier du Chromebook. La résolution automatique est conçue pour éviter d'agrandir une surface DeX plus petite que le flux scrcpy.

## 1. Mettre à jour FlipdexOS

Depuis la racine du dépôt :

```bash
git pull --ff-only origin main
chmod +x scripts/flipex-monitor.sh scripts/install-system.sh scripts/install-scrcpy-latest.sh
```

## 2. Installer le scrcpy officiel récent pour ARM64

La version recommandée est scrcpy 5.0.1. Le script télécharge le tag officiel, vérifie la somme SHA-256 du serveur Android et compile le client pour l'architecture Linux locale :

```bash
bash scripts/install-scrcpy-latest.sh
scrcpy --version
adb version
uname -m
```

Le lanceur demande au minimum scrcpy 3.3.4 pour les écrans virtuels sur Android récent. La version 5.0.1 est recommandée pour les améliorations de décodage matériel, selon les pilotes disponibles sur le Chromebook.

## 3. Vérifier le Z Flip 6 et FlipEx

Sur le téléphone :

1. Active les Options pour les développeurs et le Débogage USB.
2. Branche le téléphone en USB-C, déverrouille-le et accepte l'empreinte ADB.
3. Vérifie que FlipEx est installé et configuré avec Shizuku.
4. Dans FlipEx → Experimental → DeX window owner, essaie **Shizuku** en priorité pour éviter la fenêtre d'accessibilité appelée **FlipEx DeX screen**.
5. Laisse **Test display on the phone** désactivé : ce n'est pas nécessaire à la capture scrcpy.

Sur le Chromebook :

```bash
adb devices -l
adb shell getprop ro.build.version.sdk
adb shell dumpsys package dev.ved.flipdex | grep -E 'versionName|targetSdk'
```

Pour One UI 9 / Android 17, le SDK Android attendu est 37. Si l'APK FlipEx indique **targetSdk=36**, son avertissement de compatibilité provient de l'application Android. FlipdexOS ne peut pas changer le manifeste ni reconstruire l'APK FlipEx à distance; son dépôt Android doit être mis à jour et testé séparément.

## 4. Démarrer avec la résolution sans suréchantillonnage

Depuis la racine de FlipdexOS :

```bash
bash scripts/flipex-monitor.sh --check
bash scripts/flipex-monitor.sh --list
bash scripts/flipex-monitor.sh
```

Le mode par défaut détecte l'écran actif et adapte le petit côté à la surface actuellement rendue par FlipEx (1080 pixels maximum). Exemples :

| Résolution de l'écran du Chromebook | Résolution virtuelle utilisée |
|---|---:|
| 1920 × 1200 (16:10) | 1728 × 1080 |
| 1920 × 1080 (16:9) | 1920 × 1080 |
| 3840 × 2160 (4K) | 1920 × 1080 |

Le profil utilise H.264, 20 Mbit/s, 30 FPS, un tampon vidéo minimal et désactive la réduction automatique de résolution lorsqu'elle est prise en charge. Il ne demande plus un flux 4K artificiel au-dessus d'une source DeX 1080p.

Pour forcer manuellement le profil correspondant à un écran 16:10 ou 16:9 :

```bash
flipex-monitor --display 1728x1080/160
flipex-monitor --display 1920x1080/160
```

Pour garder une image nette, conserve la fenêtre scrcpy à sa taille native plutôt que de l'étirer en plein écran. Une mise à l'échelle fractionnaire du bureau Linux peut aussi adoucir les bords.

## 5. Valider souris, clavier et qualité puis envoyer le rapport

Le mode souris par défaut est **sdk** : le curseur reste libre sur le Chromebook et les événements de clic sont transmis à Android. Teste clic gauche, clic droit, molette, glisser-déposer et déplacement des fenêtres DeX. Si une application ignore les événements SDK, compare :

```bash
flipex-monitor --mouse uhid
```

En mode **uhid**, le pointeur est capturé; **Alt gauche** le libère et le reprend. Le clavier est transmis en mode HID; configure la disposition physique du Z Flip 6 en Français (AZERTY).

Pour arrêter, ferme la fenêtre scrcpy. En cas de problème, copie ce rapport :

```bash
uname -a
cat /etc/os-release
xrandr --current 2>/dev/null || true
adb devices -l
adb shell getprop ro.build.version.sdk
adb shell dumpsys package dev.ved.flipdex | grep -E 'versionName|targetSdk'
scrcpy --version
bash scripts/flipex-monitor.sh --check
```

Indique si le défaut concerne la netteté, les saccades, le pointeur, le clavier ou le bureau DeX. Masque le numéro de série ADB avant de partager le rapport.

**Limite connue :** le code Android FlipEx actuel plafonne sa surface DeX interne à 1080 pixels sur le petit côté. Ce dépôt peut aligner précisément la capture avec cette surface, mais une définition DeX native 1440p/4K exige une modification puis une nouvelle compilation du projet Android FlipEx lui-même.
