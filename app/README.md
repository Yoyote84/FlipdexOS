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
La CI la publie comme artefact. Elle est signée par la clé debug Android du runner ;
ce n'est pas une release de production. La signature release personnelle est décrite dans [RELEASE_SIGNING.md](RELEASE_SIGNING.md).

## Première utilisation sur le téléphone

1. Installer FlipdexOS APK.
2. Pour activer le diagnostic privilégié, ouvrir Shizuku et démarrer son serveur en mode ADB.
3. Dans FlipdexOS, appuyer sur « Vérifier et connecter Shizuku », puis autoriser l'application.
4. Vérifier que le diagnostic retourne UID 2000 et les réglages du téléphone.
5. Shizuku n'est pas requis pour la session de bureau externe démarrée via ADB et scrcpy.

Le bouton d'aperçu ouvre le bureau sur l'écran actuel. La session réelle sur le
Chromebook est lancée par le client Linux, qui démarre `DesktopActivity` sur
l'écran virtuel scrcpy.
