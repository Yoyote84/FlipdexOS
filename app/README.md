# FlipdexOS Android

APK compagnon + lanceur de bureau secondaire pour le Samsung Galaxy Z Flip6.

## Développement

Prérequis :
- JDK 17 ;
- Gradle 9.6.0 ;
- Android SDK Platform 37 et Build Tools 37 ;
- serveur Shizuku installé et démarré sur le téléphone pour les diagnostics privilégiés.

Commandes depuis la racine du dépôt :

```bash
bash tests/android-logic-tests.sh
gradle :app:assembleDebug
```

L'APK debug est générée dans `app/build/outputs/apk/debug/app-debug.apk`.
La CI la publie comme artefact. Elle est signée par la clé debug Android de CI ;
ce n'est pas encore une release de production signée par une clé personnelle.

## Première utilisation sur le téléphone

1. Installer FlipdexOS APK.
2. Ouvrir Shizuku, démarrer le serveur en mode ADB et autoriser FlipdexOS.
3. Dans FlipdexOS, appuyer sur « Vérifier et connecter Shizuku ».
4. Vérifier que le diagnostic retourne UID 2000 et les réglages du téléphone.

Le bouton d'aperçu ouvre le bureau sur l'écran actuel. La session réelle sur le
Chromebook est lancée par le client Linux, qui démarre `DesktopActivity` sur
l'écran virtuel scrcpy.
