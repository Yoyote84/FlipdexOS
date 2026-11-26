# FlipdexOS

FlipdexOS fournit un bureau Android secondaire pour le **Samsung Galaxy Z Flip6**, affiché dans une fenêtre Linux sur le **Lenovo Chromebook Duet MediaTek Helio P60T, sous postmarketOS + Plasma Desktop**.

Le projet comporte deux applications distinctes :

- **APK Android** : installée sur le Z Flip6. Elle fournit le panneau compagnon, le diagnostic Shizuku et le lanceur d'applications du bureau secondaire.
- **Flatpak ARM64 / client Linux** : installé sur le Chromebook. Il utilise ADB et scrcpy pour créer un écran virtuel Android et ouvrir notre propre activité de bureau dans une fenêtre Plasma.

L'objectif est que l'écran principal du téléphone reste utilisable indépendamment pendant que le bureau est affiché sur le Chromebook.

> **État : première APK debug compilée.** Le module Android indépendant compile contre API 37 et ses tests sont verts. L'APK de test a été publiée par GitHub Actions et vérifiée par SHA-256. Le test sur le Z Flip6 réel et la validation du Flatpak sur le Chromebook restent à faire.

## Architecture

1. Le Z Flip6 exécute FlipdexOS ; Shizuku est facultatif pour la session de bureau externe.
2. Quand Shizuku fonctionne et que l'utilisateur autorise l'application, FlipdexOS lie un UserService limité à une liste précise de propriétés et de réglages Android.
3. Le Chromebook se connecte au téléphone par USB et ADB.
4. scrcpy crée un **nouvel écran virtuel**, indépendant de l'écran principal.
5. scrcpy démarre le paquet `io.github.yoyote84.flipdexos` sur cet écran avec `--start-app`. Son activité compagnon détecte qu'elle n'est pas sur l'écran principal et redirige vers `DesktopActivity`.
6. Le bureau FlipdexOS affiche les applications installées et les lance sur le même écran secondaire.

Le bureau est encore un premier lanceur d'applications : une barre des tâches complète, la gestion avancée des fenêtres, les bureaux multiples et les raccourcis système restent à construire et à tester.

## Application Android — Galaxy Z Flip6

Le code se trouve dans `app/`.

Fonctions de cette première version :
- panneau compagnon affichant le téléphone et la version Android ;
- connexion au Binder Shizuku et demande de permission utilisateur ;
- UserService AIDL exécuté avec l'identité shell Shizuku ;
- diagnostic UID, Android, One UI et de trois réglages de mode bureau ;
- aperçu du bureau sur l'écran actuel ;
- activité de bureau redimensionnable, liste des applications, recherche et lancement sur le même écran.

Le service Shizuku ne fournit **aucun exécuteur de commande arbitraire**. Ses appels sont limités à quatre propriétés système connues et trois réglages globaux nommément autorisés. Les valeurs insérées sont strictement limitées à `0` ou `1`. L'interface compagnon ne modifie pas les réglages automatiquement à son ouverture.

### Compatibilité Android 17

- `compileSdk 37` : accès aux API Android 17.
- `targetSdk 36` : conservé provisoirement, le temps de vérifier les changements de comportement Android 17 et One UI 9.
- `minSdk 31` : Android 12 minimum.
- Android Gradle Plugin 9.4.0, Gradle 9.6.0 et JDK 17.

### Récupérer l'APK de test

Le workflow [Construire l'APK Android FlipdexOS](https://github.com/Yoyote84/FlipdexOS/actions/workflows/android.yml) compile et teste le module, puis publie un artefact nommé `flipdexos-android-debug-apk`.

Après réussite du workflow :
1. ouvre l'exécution depuis l'onglet Actions ;
2. télécharge l'artefact et extrais l'archive ;
3. installe l'APK sur le Z Flip6 :

```bash
adb install -r app-debug.apk
```

L'APK de CI est une version **debug signée par la clé Android de CI** : elle sert aux essais et ne remplace pas encore une release de production signée avec une clé privée contrôlée par l'utilisateur.

### Premier démarrage sur le téléphone

1. Installe et ouvre FlipdexOS.
2. Installe Shizuku depuis sa source officielle.
3. Pour les diagnostics privilégiés du panneau Android, démarre le serveur Shizuku en mode ADB ou via le débogage sans fil Android.
4. Dans FlipdexOS, appuie sur **Vérifier et connecter Shizuku** puis autorise l'application.
5. Vérifie que le diagnostic affiche l'UID 2000 lorsque le service Shizuku fonctionne avec l'identité ADB shell. Cette étape est facultative pour lancer le bureau depuis le Chromebook.

Le bouton **Aperçu du bureau sur ce téléphone** permet de vérifier le lanceur avant le test sur l'écran virtuel.

## Client Linux / Chromebook

La cible principale est le Lenovo Chromebook Duet sous postmarketOS/Alpine et Plasma. Debian/Ubuntu restent des cibles secondaires.

### Installer ADB et scrcpy sur postmarketOS

Depuis la racine du dépôt :

```bash
bash scripts/install-scrcpy-latest.sh
/usr/local/bin/scrcpy --version
adb version
uname -m
```

Le script utilise `apk`, installe les dépendances SDL3/FFmpeg/libusb, récupère le serveur officiel scrcpy, vérifie sa somme SHA-256 puis compile le client pour l'architecture locale. Il utilise `doas` ou `sudo` pour l'installation système.

scrcpy 5.0.1 ou une version plus récente est requis pour le profil de bureau virtuel utilisé ici. Si la base postmarketOS ne fournit pas SDL3, ne mélange pas les dépôts Alpine edge à une base stable : il faut d'abord mettre à jour la distribution.

### Installer le lanceur Plasma

```bash
bash scripts/install-system.sh --user
```

Le menu Plasma affiche **FlipdexOS — Connexion**. Le nom de commande historique reste `flipex-monitor` afin de ne pas casser les scripts et les habitudes existants.

### Préparer le téléphone

- activer les options développeur et le débogage USB ;
- brancher et déverrouiller le Z Flip6 ;
- accepter l'empreinte RSA ADB ;
- démarrer Shizuku et accorder la permission à FlipdexOS uniquement si tu veux activer le UserService du panneau Android. Shizuku n'est plus un prérequis pour la session bureau ADB/scrcpy.

Puis, sur le Chromebook :

```bash
adb devices -l
bash scripts/diagnose-flipex-android.sh
bash scripts/flipex-monitor.sh --check
bash scripts/flipex-monitor.sh
```

Le script vérifie la présence du paquet FlipdexOS ; Shizuku est diagnostiqué de façon non bloquante. ADB shell est utilisé directement pour sauvegarder/restaurer les réglages et lancer le bureau virtuel. Il sauvegarde les valeurs initiales des trois réglages de mode bureau avant de les changer, puis les restaure à la fermeture de scrcpy. En cas d'arrêt brutal, utilise :

```bash
flipex-monitor --restore
```

La présence du processus Shizuku ne prouve pas à elle seule que le Binder est actif. Le panneau Android effectue le contrôle Binder/UserService. Un problème Shizuku n'empêche plus le démarrage du bureau externe.

### Résolution, souris et clavier

La résolution automatique privilégie `kscreen-doctor`, puis essaie `wlr-randr` et `xrandr`. Le profil reste conservateur (petit côté de 1080 pixels) pour la netteté et les performances du Helio P60T.

Exemples :

```bash
flipex-monitor --display 1728x1080/160
flipex-monitor --display 1920x1080/160
flipex-monitor --flex-display
flipex-monitor --mouse uhid
flipex-monitor --keyboard sdk
```

La souris par défaut utilise le mode SDK, le curseur reste libre dans Plasma. Le mode `uhid` simule une souris physique Android et capture le pointeur ; Alt gauche libère ou reprend la capture. Le clavier du Chromebook est envoyé au téléphone ; configure le clavier physique Android en Français (AZERTY).

## Flatpak pour le Chromebook ARM64

Le Flatpak est séparé de l'APK Android. Il cible `aarch64`, Plasma et le runtime Freedesktop 26.08.

Méthode recommandée : récupérer le bundle produit par [la CI Flatpak ARM64](https://github.com/Yoyote84/FlipdexOS/actions/workflows/flatpak.yml), télécharger l'artefact `flipdexos-monitor-flatpak-aarch64`, puis l'installer sur le Chromebook :

```bash
flatpak install --user --bundle ./flipdexos-monitor-aarch64.flatpak
flatpak run io.github.yoyote84.flipdexos
```

ADB et scrcpy restent installés sur l'hôte afin d'utiliser ses accès USB et son compositeur Plasma. Le Flatpak utilise `flatpak-spawn --host` et une liste blanche de commandes hôte. Le droit D-Bus requis est puissant : ce paquet est destiné à une installation locale de confiance, pas à une publication Flathub en l'état.

Pour construire localement :

```bash
bash scripts/build-flatpak.sh --install
```

## Tests et diagnostic

Depuis la racine du dépôt :

```bash
bash -n scripts/flipex-monitor.sh
bash tests/fake-tools.sh
bash tests/flipex-android-preflight.sh
bash tests/flatpak-packaging.sh
bash tests/android-logic-tests.sh
gradle :app:assembleDebug
```

Les workflows GitHub Actions exécutent les tests du client Linux, construisent le Flatpak ARM64, compilent l'APK debug et vérifient le démarrage du panneau compagnon et de DesktopActivity sur un émulateur Android 16. Le workflow de publication release est manuel et nécessite les secrets de signature personnels. Ces tests automatisés ne remplacent pas l'essai sur le Chromebook et le Z Flip6 physiques.

## Licences et provenance

Le code original du module Android FlipdexOS est publié sous licence MIT : [app/LICENSE](app/LICENSE).

- **Shizuku API / Provider 13.1.5** : bibliothèque MIT, utilisée comme dépendance Maven ; aucune source Shizuku n'est copiée.
- **scrcpy** : Apache-2.0, exécuté comme outil hôte sur le Chromebook et non incorporé à l'APK.
- **android-desk** : GPL-3.0, consulté comme référence fonctionnelle ; aucun fichier source n'est copié.
- **FlipEx** : aucune licence de réutilisation déclarée dans le dépôt source audité ; son code n'est pas repris.

Voir [les notices tierces](app/THIRD_PARTY_NOTICES.md), [l'architecture Android](docs/ANDROID_APP_ARCHITECTURE.md), [la signature de publication](app/RELEASE_SIGNING.md) et [le bilan de l'étape 5](docs/STEP_5_FINAL_VALIDATION.md).

FlipdexOS est un projet indépendant, non développé ni approuvé par Samsung, RikkaApps, Genymobile ou les auteurs de FlipEx.
