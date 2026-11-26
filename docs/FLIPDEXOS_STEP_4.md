# FlipdexOS — étape 4/5 : paquets et compilation

Date : 2026-11-26

## Résumé et périmètre

Les livrables attendus sont séparés :

- **APK Android : Samsung Galaxy Z Flip6**, pour FlipEx et son fonctionnement DeX.
- **Flatpak Linux ARM64 : Lenovo Chromebook Duet**, MediaTek Helio P60T, postmarketOS et Plasma Desktop.

Le dépôt FlipdexOS contient aujourd'hui le client Linux, les scripts de diagnostic et de pilotage, mais aucun module Android `app/` à compiler. Le Flatpak est donc traité directement dans ce dépôt ; la génération de l'APK dépend toujours du projet Android tiers FlipEx.

## Flatpak Chromebook

### Choix technique

Le paquet est ciblé sur `aarch64` et utilise `org.freedesktop.Platform` / `org.freedesktop.Sdk` 26.08. Cette branche est la version Freedesktop actuelle en novembre 2026 et sa maintenance est prévue jusqu'en septembre 2028.

Le Flatpak reste volontairement léger : il embarque le client FlipdexOS et son lanceur, mais réutilise sur le système hôte les exécutables `adb`, `scrcpy`, `kscreen-doctor`, `wlr-randr`, `xrandr` et les outils de notification. Sur ce Chromebook, ADB doit accéder au bus USB du téléphone et scrcpy doit ouvrir une fenêtre native Plasma ; compiler puis exécuter ces deux outils dans un environnement isolé différent compliquerait inutilement l'accès USB, l'affichage et la gestion du serveur ADB.

Le lanceur utilise `flatpak-spawn --host` avec une liste blanche fixe de commandes. Le manifeste accorde uniquement `--talk-name=org.freedesktop.Flatpak` pour ce pont. Il n'accorde pas `--device=all`, `--filesystem=home` ni l'accès réseau dans le bac à sable. Les fichiers d'état de l'application restent dans l'espace de configuration propre au Flatpak.

**Limite de sécurité importante :** le droit de parler au service `org.freedesktop.Flatpak` permet techniquement à une application compromise de tenter de lancer des commandes hôte. Le lanceur fourni limite les exécutables qu'il relaie, mais ce contrôle n'est pas une frontière de sécurité contre du code malveillant dans l'application. Ce paquet est donc destiné à une installation locale de confiance ; il n'est pas prêt pour Flathub. Une publication publique devrait remplacer ce mécanisme par une API/permission hôte plus restrictive ou une intégration native dédiée.

### Compilation et installation sur le Chromebook

Prérequis : Flatpak et flatpak-builder installés sur postmarketOS. ADB et scrcpy doivent déjà être présents sur l'hôte. La procédure de référence depuis le dépôt est :

```bash
bash scripts/install-scrcpy-latest.sh
bash scripts/build-flatpak.sh --install
```

Le script vérifie l'architecture Flatpak `aarch64`, ajoute Flathub si nécessaire, résout le runtime et le SDK 26.08, construit le bundle, vérifie la somme SHA-256 et l'installe dans le profil de l'utilisateur.

Pour seulement produire le paquet :

```bash
bash scripts/build-flatpak.sh
```

La sortie attendue est `dist/flipdexos-monitor-0.10.0-aarch64.flatpak` et son fichier `.sha256`. Le paquet apparaît ensuite dans le menu Plasma sous **FlipdexOS — FlipEx Monitor**. Le menu ouvre un terminal afin de conserver les diagnostics, puis le bureau virtuel scrcpy s'ouvre dans sa propre fenêtre.

### Validation automatisée

- Test de syntaxe POSIX du lanceur et du pont hôte.
- Vérification statique du manifeste, du runtime et des permissions.
- Test simulé de la transmission des arguments à ADB par `flatpak-spawn`.
- Vérification qu'un nom d'exécutable qui n'est pas dans la liste blanche est refusé.
- Construction réelle du bundle sur un runner GitHub Actions ARM64 natif (`ubuntu-24.04-arm`).
- Publication du bundle et de son SHA-256 comme artefacts de la compilation CI.

La construction CI ne remplace pas le test USB/Plasma sur le Lenovo Duet réel.

## APK Android — Galaxy Z Flip6

### État vérifié du projet source

Le dépôt officiel public [Vedjamkar/flipex](https://github.com/Vedjamkar/flipex), branche `main`, a été vérifié le 26 novembre 2026 :

- commit courant : `6bfdeb9f779bf921e659baf614a08021bcb529ec`, version source `0.3.4` ;
- dernière release GitHub publiée : `v0.3.0`, datée du 15 novembre 2026 ;
- la propriété GitHub `license` est nulle et l'arborescence ne contient pas de fichier `LICENSE` ;
- `app/build.gradle` déclare `compileSdk 36`, `targetSdk 36`, `minSdk 31`, Java 17 et Android Gradle Plugin 9.4.0 ;
- le dépôt ne contient pas de Gradle Wrapper.

La disponibilité publique du code source n'est pas une autorisation de le modifier, de le redistribuer ou de republier un APK dérivé. FlipdexOS ne copie donc pas ce code tiers et ne fabrique pas un APK factice. L'APK `v0.3.0` existant n'est pas présenté comme une compilation à jour de la source `0.3.4`.

### Compatibilité Android 17

La documentation officielle Android 17 indique `compileSdk = 37`. Elle recommande de relever aussi `targetSdk` à 37 lorsque l'application est prête à adopter et tester les nouveaux comportements d'exécution. Il ne faut pas relever mécaniquement `targetSdk` avant de vérifier les fenêtres virtuelles, les services privilégiés Shizuku, les permissions et les restrictions de démarrage en arrière-plan sur One UI 9.

Aucune APK nouvelle n'est produite à ce stade : cela nécessiterait soit une autorisation écrite/licence du mainteneur permettant les modifications et la redistribution, soit une application Android indépendante créée proprement, sans reprendre le code FlipEx.

### Conditions pour débloquer le livrable APK

1. Obtenir du mainteneur une licence explicite ou une autorisation écrite couvrant la modification et la distribution de l'APK ; ou lancer une implémentation Android indépendante.
2. Définir la cible `compileSdk 37` et conserver provisoirement `targetSdk 36` jusqu'aux tests de comportement Android 17.
3. Ajouter une compilation reproductible, des tests unitaires et des contrôles de manifeste.
4. Signer l'APK avec une clé contrôlée par l'utilisateur, stockée hors du dépôt et de GitHub.
5. Installer et valider sur le Galaxy Z Flip6 : démarrage Shizuku, Binder/UserService, affichage virtuel, fenêtre, saisie et restauration après arrêt.

Ce blocage est indépendant du Flatpak : le Flatpak Chromebook peut être compilé et validé sans modifier le code Android tiers.

## Verdict de l'étape 4

**Flatpak :** packaging ARM64 intégré au dépôt ; la compilation réelle et les tests sont exécutés par le workflow CI ajouté. Le test sur le matériel Chromebook reste à faire.

**APK Z Flip6 :** non produit, car aucune source Android intégrée ou autorisation de réutilisation du dépôt tiers n'est disponible. Il serait trompeur de déclarer l'étape 4 totalement terminée tant que ce point n'est pas débloqué.

## Sources

- [FlipEx upstream — dépôt et licence](https://github.com/Vedjamkar/flipex)
- [FlipEx upstream — code Gradle Android](https://github.com/Vedjamkar/flipex/blob/main/app/build.gradle)
- [FlipEx upstream — dernière release publiée](https://github.com/Vedjamkar/flipex/releases/latest)
- [Android Developers — configurer le SDK Android 17](https://developer.android.com/about/versions/17/setup-sdk)
- [Flatpak — manifestes](https://docs.flatpak.org/en/latest/manifests.html)
- [Flatpak — permissions du bac à sable](https://docs.flatpak.org/en/latest/sandbox-permissions.html)
- [Freedesktop SDK — support des versions](https://freedesktop-sdk.gitlab.io/documentation/wiki/Releases.html)
- [GitHub Actions — runners ARM64](https://docs.github.com/en/actions/reference/runners/github-hosted-runners)
