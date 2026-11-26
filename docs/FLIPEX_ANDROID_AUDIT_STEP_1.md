# FlipEx Android — audit de l'étape 1/5

Date de l'audit : 2026-11-26

## Périmètre et méthode

Audit statique du dépôt public [Vedjamkar/flipex](https://github.com/Vedjamkar/flipex), branche `main`, commit examiné : `6bfdeb9f779bf921e659baf614a08021bcb529ec` (version publiée `v0.3.4-alpha`).

Fichiers examinés : README, configuration Gradle, manifeste Android, `MainActivity`, `DexSettings`, `Shell`, `ShellService`, `ShellDexLayer`, `DexScreen`, `DexA11yService`, `FoldWatcherService`, `Updater`, `Diagnostics`, `TrackpadActivity`, `UpdateReceiver` et workflow GitHub Actions.

Aucun fichier du dépôt original FlipEx n'a été modifié. Aucun APK n'a été compilé et aucun essai matériel n'a été exécuté pendant cette étape.

## Résumé exécutif

FlipEx est une application Android Java qui tente de fournir un environnement de type DeX sur les Galaxy Z Flip en assemblant le mode bureau Android, le lanceur Samsung secondaire et des mécanismes de fenêtre/affichage virtuel. Le projet dépend fortement de Shizuku pour obtenir les privilèges shell sans root et s'appuie sur plusieurs API Android cachées ou réfléchies.

La branche étudiée détecte automatiquement One UI 8.5 et versions ultérieures pour emprunter la route « écran virtuel ». Cela rend cette route candidate sur One UI 9, mais ne constitue pas une preuve de compatibilité Android 17 / API 37. Le README du projet annonce surtout One UI 8 / Android 16 et décrit la 8.5 comme expérimentale.

## Constatations

### 1. Compatibilité Android déclarée — risque élevé

- `app/build.gradle` : `compileSdk 36`, `targetSdk 36`, `minSdk 31`, Java 17, version `0.3.4`.
- Le Galaxy Z Flip6 de test est sous Android 17 / API 37 et One UI 9.
- `DexSettings.oneUiVersion()` lit `ro.build.version.oneui`; `isOneUi85OrLater()` active la route virtuelle dès la version 8.5.
- Cette détection est seulement un aiguillage. Elle ne garantit pas que les signatures cachées, les services système et les règles de permission soient identiques sur One UI 9.

**Conclusion :** préparer une compilation avec SDK 37, mais conserver provisoirement la cible API 36 tant que les changements de comportement liés à targetSdk 37 ne sont pas testés.

### 2. Dépendance Shizuku — risque bloquant à vérifier en premier

- FlipEx utilise `dev.rikka.shizuku:api:13.1.5` et `provider:13.1.5`.
- `Shell.connect()` lie `ShellService` en tant que UserService Shizuku. Le service exécute des commandes sous l'identité shell et pilote les opérations système.
- Sans Shizuku actif et autorisé, les réglages privilégiés, la création de l'écran virtuel et le pointeur HID ne peuvent pas suivre le chemin normal de FlipEx.
- Un signalement officiel Shizuku (#2681) documente des problèmes après passage à One UI 9 / Android 17, notamment liste des applications autorisées et App Ops. D'autres utilisateurs Samsung ont commenté le même signalement.

**Limite de preuve :** ce signalement ne prouve pas que le Binder UserService précis utilisé par FlipEx échoue sur le Z Flip6. Il rend indispensable un test ciblé de Shizuku et du UserService avant de changer les autres composants.

### 3. Fragilité des API système — risque élevé

Le code dépend de méthodes et structures non garanties comme API publiques stables :

- `IDisplayManager.createVirtualDisplay` et `releaseVirtualDisplay`, trouvées par réflexion ;
- `SurfaceControl` / transactions SurfaceFlinger dans `ShellDexLayer` ;
- méthodes cachées d'InputManager pour associer les périphériques à un écran ;
- réflexion sur ActivityTaskManager et les champs des tâches ;
- méthodes de gestion du mode bureau et de politique clavier ;
- commandes `wm shell desktopmode` et propriétés internes Samsung.

Plusieurs recherches de méthodes se basent sur le nom et le nombre de paramètres. Une modification de signature ou de permission sur API 37 peut donc interrompre une fonction sans erreur de compilation évidente.

### 4. Restauration des réglages — défaut fonctionnel identifié

- `DexSettings.enableA11y()` ajoute le service d'accessibilité FlipEx dans `ENABLED_ACCESSIBILITY_SERVICES` et active le réglage global d'accessibilité.
- `DexSettings.restoreStock()` restaure plusieurs réglages DeX et l'option de poignée plein écran, mais ne retire pas explicitement le service FlipEx de la liste d'accessibilité et ne restaure pas l'état antérieur d'accessibilité globale.
- Le mode de propriétaire de fenêtre `dex_window` reste également mémorisé après restauration.
- `KEY_MIRROR_SAVED` et `getMirrorSetting()` sont déclarés, mais l'audit du code courant n'a pas trouvé de chemin qui sauvegarde effectivement cette valeur avant restauration. Cette partie semble incomplète ou résiduelle.

**Correction à prévoir :** sauvegarder les états précédents, ne restaurer que ce que FlipEx a modifié, retirer uniquement le composant FlipEx si l'application l'a elle-même activé et préserver les autres services d'accessibilité.

### 5. Exécution des commandes shell — robustesse à améliorer

`ShellService.exec()` fusionne stdout/stderr et renvoie le texte, mais ne vérifie pas le code de sortie du processus et n'impose pas de délai maximal. Plusieurs appels considèrent un résultat non nul comme une réussite. Un message d'erreur renvoyé par `settings` ou `wm` peut donc être interprété à tort comme une opération réussie.

**Correction à prévoir :** rendre le résultat structuré (code retour, sortie, erreur), ajouter un timeout, journaliser la commande/opération sans données sensibles et traiter explicitement les erreurs.

### 6. Qualité de validation et livraison — risque élevé

- Le seul workflow présent, `.github/workflows/desktop.yml`, construit les clients Tauri pour macOS et Windows.
- Aucun workflow Android de compilation/test n'a été identifié.
- Aucun répertoire `app/src/test` ou `app/src/androidTest` n'a été identifié.
- Le dépôt n'inclut pas de Gradle Wrapper ; le README demande JDK 17+ et Gradle 9.
- L'APK de la release est publié comme asset, mais le workflow examiné ne construit pas cet APK Android.

**Conséquence :** l'état vert du workflow Desktop ne valide ni la compilation Android ni le fonctionnement de FlipEx sur API 37.

### 7. Limites déjà reconnues par l'auteur

La release `v0.3.4-alpha` est explicitement expérimentale et destinée aux retours One UI 8.5. Ses notes indiquent notamment l'absence de fond d'écran sur l'écran DeX virtuel et un rendu plafonné à une surface Full HD (puis mise à l'échelle sur les écrans plus grands). Les améliorations de poignée des applications maximisées et de masquage immédiat en état verrouillé n'étaient pas encore confirmées sur appareil One UI 8.5.

### 8. Licence — vérification préalable indispensable

Les métadonnées GitHub ne déclarent aucune licence et aucun fichier de licence n'a été trouvé dans l'arborescence examinée. L'accès public au dépôt ne vaut pas autorisation générale de redistribuer ou de publier une version dérivée.

**Avant de copier, modifier, intégrer ou redistribuer le code FlipEx**, obtenir une licence explicite ou l'autorisation du mainteneur. L'audit et les liens vers le dépôt peuvent être documentés dans FlipdexOS sans recopier son code.

## Priorités proposées pour l'étape 2/5

1. Vérifier l'autorisation/licence de réutilisation auprès du mainteneur FlipEx.
2. Tester séparément Shizuku sur le Z Flip6 One UI 9 : serveur actif, autorisation accordée, Binder accessible et liaison UserService FlipEx fonctionnelle.
3. Mettre la chaîne Android en mesure de compiler avec `compileSdk 37`, sans relever automatiquement `targetSdk` avant les tests.
4. Ajouter une CI Android (JDK/Gradle/SDK explicites), compilation debug, tests unitaires des décisions de version/réglages et contrôles du manifeste.
5. Corriger la sauvegarde/restauration de l'accessibilité et fiabiliser les commandes shell.
6. Tester progressivement la création, l'affichage, la fermeture et la reconnexion de l'écran virtuel avec HDMI et avec scrcpy, sans bloquer le retour au miroir standard en cas d'échec.

## Verdict de l'étape 1/5

**Audit statique terminé.** Les principaux risques sont identifiés, mais la compatibilité Android 17 / One UI 9 n'est pas démontrée. Aucun correctif ni APK n'est livré à cette étape. Le premier jalon technique de l'étape 2 doit être la validation Shizuku/UserService sur le téléphone réel, car toute la chaîne privilégiée de FlipEx en dépend.

## Sources

- [Code source FlipEx — commit audité](https://github.com/Vedjamkar/flipex/tree/6bfdeb9f779bf921e659baf614a08021bcb529ec)
- [Release FlipEx v0.3.4-alpha et limites déclarées](https://github.com/Vedjamkar/flipex/releases/tag/v0.3.4-alpha)
- [Issue FlipEx #1 — écran miroir et historique des correctifs](https://github.com/Vedjamkar/flipex/issues/1)
- [Issue FlipEx #2 — comportement des écrans externes One UI 8.5](https://github.com/Vedjamkar/flipex/issues/2)
- [Issue Shizuku #2681 — signalement One UI 9 / Android 17](https://github.com/RikkaApps/Shizuku/issues/2681)
- [Documentation Android 17 — configuration SDK](https://developer.android.com/about/versions/17/setup-sdk)
