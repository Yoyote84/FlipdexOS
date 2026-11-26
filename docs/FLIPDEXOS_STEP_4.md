# FlipdexOS — étape 4/5 : application Android et paquets

Date : 2026-11-26

## Livrables et appareils

- **APK Android** : Samsung Galaxy Z Flip6, Android 17 / One UI 9.
- **Flatpak ARM64 + client Linux** : Lenovo Chromebook Duet MediaTek Helio P60T, postmarketOS/Alpine et Plasma Desktop.

Les deux programmes sont distincts : le téléphone fournit l'application compagnon et le lanceur du bureau Android ; le Chromebook crée et capture l'écran virtuel à l'aide d'ADB et scrcpy.

## Application Android originale

Le module Android est maintenant intégré dans `app/`, identifiant :

```
io.github.yoyote84.flipdexos
```

### Fonctions livrées dans le premier socle

- `MainActivity` : panneau compagnon, modèle/version Android, état Binder Shizuku, demande d'autorisation et rapport du UserService.
- `ShellUserService` + AIDL : service privilégié via Shizuku, vérification de l'UID et lecture de propriétés/réglages connus.
- Liste blanche stricte : quatre propriétés système et trois réglages globaux autorisés ; aucune exécution shell arbitraire.
- `DesktopActivity` : lanceur secondaire redimensionnable, liste des applications exposées par Android, recherche et ouverture d'une application sur le même écran via `ActivityOptions.setLaunchDisplayId()`.
- Tests unitaires des listes blanches, des valeurs de réglage et du format de version One UI.
- Workflow GitHub Actions Android : compilation `debug`, tests JUnit, génération SHA-256 et publication de l'APK de test.

Le client Chromebook a été mis à jour pour vérifier notre paquet Android et passer `--start-app=io.github.yoyote84.flipdexos` à scrcpy. `MainActivity` redirige ensuite vers `DesktopActivity` lorsqu'elle est lancée sur l'écran virtuel ; le panneau compagnon reste la page d'accueil du téléphone.

### Configuration de compilation

- `compileSdk 37` pour Android 17.
- `targetSdk 36` provisoire ; on ne relève pas ce niveau avant les tests des nouveaux comportements Android 17.
- `minSdk 31`.
- Android Gradle Plugin 9.4.0, Gradle 9.6.0, JDK 17.
- Dépendance Shizuku API / Provider 13.1.5 sous licence MIT.

L'APK produite par CI est une version debug, signée avec la clé debug du runner. Elle peut servir à l'installation et aux essais, mais n'est pas encore une version de production signée par une clé privée contrôlée par l'utilisateur.

### Provenance du code

Aucun code source FlipEx n'est copié. La licence du dépôt FlipEx n'était pas déclarée dans les métadonnées GitHub lors de l'audit.

Le projet `android-desk` est sous GPL-3.0 ; il a été consulté comme référence, sans copier ses fichiers source. scrcpy est Apache-2.0 et utilisé comme outil hôte externe. Shizuku-API est MIT et consommé comme bibliothèque Maven. Le code original de notre module Android est MIT. Voir [app/THIRD_PARTY_NOTICES.md](../app/THIRD_PARTY_NOTICES.md).

## Client Linux et Flatpak ARM64

Le client hôte garde le contrôle des sauvegardes/restaurations du mode bureau et du transport vidéo. Il démarre notre propre `DesktopActivity` directement sur l'écran virtuel scrcpy. L'écran principal du Z Flip6 reste indépendant.

Le Flatpak utilise Freedesktop 26.08 sur `aarch64`. ADB et scrcpy restent installés sur l'hôte pour accéder à l'USB et au compositeur Plasma. Le bridge `flatpak-spawn --host` est limité à une liste blanche fixe, mais l'accès D-Bus correspondant reste puissant : le Flatpak est prévu pour un usage local de confiance et n'est pas prêt pour Flathub.

Le bundle Flatpak est construit dans la CI ARM64 native et publié comme artefact de workflow. La procédure d'installation est dans le [README](../README.md).

## Validation à effectuer

Les tests automatisés valident la compilation, le packaging et les comportements simulés. Ils ne prouvent pas encore :
- la liaison réelle du Binder Shizuku sur One UI 9 ;
- l'ouverture de la nouvelle activité dans l'écran virtuel sur le Z Flip6 ;
- le lancement multi-écran de toutes les applications ;
- la fluidité et la netteté sur le Helio P60T/Plasma.

Le premier test matériel doit commencer par l'autorisation Shizuku, puis le diagnostic du panneau Android, l'installation de l'APK, le lancement du Flatpak et le test de quelques applications sur le second écran.

## Verdict

**Socle de code Android :** créé dans FlipdexOS, code original MIT, build CI ajouté.

**APK debug :** disponible comme artefact après réussite du workflow Android ; elle ne constitue pas encore une release signée de production.

**Flatpak :** manifeste et pipeline ARM64 présents ; installation réelle et validation sur le Chromebook en attente.

**Étape 4 :** reste à confirmer par les builds CI et les tests matériels. L'étape 5 sera dédiée à la validation et aux corrections observées sur le Z Flip6 et le Chromebook.

## Sources

- [SDK Android 17 — compileSdk 37](https://developer.android.com/about/versions/17/setup-sdk)
- [Android Gradle Plugin 9.4.0 — compatibilité API 37 / Gradle 9.6 / JDK 17](https://developer.android.com/build/releases/agp-9-4-0-release-notes)
- [Shizuku API — UserService](https://github.com/RikkaApps/Shizuku-API)
- [scrcpy — écran virtuel et --start-app](https://github.com/Genymobile/scrcpy/blob/master/doc/virtual-display.md)
- [android-desk — référence GPL-3.0](https://github.com/jitunayak/android-desk)
- [Flatpak — sandbox et manifeste](https://docs.flatpak.org/en/latest/sandbox-permissions.html)
