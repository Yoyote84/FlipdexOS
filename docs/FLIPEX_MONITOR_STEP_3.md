# FlipEx Monitor — étape 3/5 : DeX, Shizuku et affichage

Date : 2026-11-26

## Périmètre

L'étape 3 améliore le client Linux **FlipdexOS** qui pilote FlipEx depuis le Lenovo Chromebook Duet (MediaTek Helio P60T, postmarketOS + Plasma) vers le Galaxy Z Flip6 (One UI 9 / Android 17).

Elle ne modifie pas le code Android indépendant de FlipEx et ne produit pas d'APK. Le dépôt upstream ne déclare pas de licence de réutilisation et les permissions GitHub de cette session sont en lecture seule. Les travaux natifs Android restent donc hors de ce changement.

## Modifications appliquées dans FlipdexOS

### 1. Précontrôle Shizuku plus fiable

Avant de modifier un réglage Android, le lanceur :
- vérifie que le paquet `moe.shizuku.privileged.api` est installé ;
- lit sa version déclarée ;
- cherche un processus serveur dans `adb shell ps -A` (`shizuku_server` ou `libshizuku.so`) ;
- arrête la procédure si l'application n'est pas installée ou si aucun processus serveur n'est détecté ;
- rappelle que la présence du processus n'est **pas** une preuve que le Binder Shizuku est vivant ni que FlipEx est autorisé.

La version Android, l'API et le code One UI sont affichés au démarrage. Le lancement de FlipEx attend maintenant le résultat d'Android avec `am start -W`.

**Contrôle manuel obligatoire :** sur le téléphone, Shizuku doit afficher « en cours d'exécution » et FlipEx doit apparaître dans ses applications autorisées. L'API Shizuku expose le contrôle Binder à l'application cliente via `pingBinder()`; le script Linux ne peut pas appeler cette méthode à la place de FlipEx.

### 2. Restauration non destructive des réglages

L'ancien `--restore` forçait les trois options globales du mode bureau à `0`, même si l'utilisateur avait déjà une valeur différente. Ce comportement est supprimé.

Avant d'activer les réglages, le lanceur enregistre leurs valeurs précédentes :
- `enable_freeform_support`
- `force_desktop_mode_on_external_displays`
- `enable_non_resizable_multi_window`

En mode overlay, l'ancienne valeur de `overlay_display_devices` est aussi sauvegardée. Le fichier d'état est stocké dans `$HOME/.local/state/flipdex-monitor/` avec des permissions privées (`0600`) et un nom propre à l'identifiant ADB du téléphone. L'identifiant brut n'est pas écrit dans le fichier.

Après la fermeture normale de scrcpy, les valeurs précédentes sont automatiquement restaurées et vérifiées. Après une interruption brutale du Chromebook ou du processus, exécuter :

```bash
flipex-monitor --restore
```

La sauvegarde n'est supprimée que lorsque la restauration a été vérifiée. Si Android refuse une écriture, le fichier reste disponible pour un nouvel essai.

### 3. Résolution fixe par défaut

Le mode adaptatif `--flex-display` n'est plus activé automatiquement.

- Par défaut, la surface virtuelle reste à la résolution calculée à partir de l'écran Plasma, même si la fenêtre est redimensionnée.
- `--flex-display` devient une option volontaire pour suivre la taille de la fenêtre ; c'est utile pour économiser des ressources, mais la réduction de la fenêtre peut alors réduire la définition réellement rendue.
- `--no-vd-destroy-content` est utilisé lorsque scrcpy le prend en charge afin de déplacer les applications vers l'écran principal à la fermeture de l'écran virtuel plutôt que de les détruire.
- La politique IME est passée à `local`, pour que le clavier logiciel associé à l'écran virtuel apparaisse sur celui-ci plutôt que sur l'écran principal.

Le profil reste adapté au rendu FlipEx observé : petit côté plafonné à 1080 pixels, H.264, 20 Mbit/s, 30 FPS et tampon vidéo nul. Une capture 4K ne peut pas restaurer les détails qui n'ont pas été dessinés par une surface Android 1080p.

### 4. Diagnostic amélioré

`scripts/diagnose-flipex-android.sh` n'essaie plus de trouver Shizuku dans la liste des services système Android. Il inspecte plutôt `ps -A` et indique explicitement que ce résultat n'est qu'une observation du processus serveur, pas une validation Binder.

## Tests ajoutés ou étendus

`tests/fake-tools.sh` simule maintenant :
- Galaxy Z Flip6 sous Android 17 / One UI 9 ;
- Shizuku installé et serveur visible ;
- refus de démarrer lorsque Shizuku n'est pas installé ou que le serveur n'est pas détecté ;
- résolution fixe par défaut et `--flex-display` activé seulement à la demande ;
- restauration des trois réglages globaux à leurs anciennes valeurs ;
- restauration d'une ancienne valeur overlay après interruption simulée ;
- modes écran virtuel/overlay, souris SDK/HID et paramètres de débit/FPS.

`tests/flipex-android-preflight.sh` vérifie aussi l'observation du processus Shizuku dans le rapport.

Les tests sont simulés ; ils ne prouvent pas l'exécution du mode DeX sur le téléphone réel ni la disponibilité du Binder Shizuku dans FlipEx. GitHub Actions doit valider syntaxe, ShellCheck, tests et exécution Alpine/postmarketOS.

## Limites connues / risque restant

L'issue Shizuku [#2681](https://github.com/RikkaApps/Shizuku/issues/2681), ouverte le 11 novembre 2026, signale sous One UI 9 / Android 17 avec Shizuku 13.6.0 une absence des applications autorisées et des dysfonctionnements App Ops. Ce signalement concerne un Galaxy Tab S11 Ultra et des retours d'autres appareils ; il ne prouve pas que le Binder UserService de FlipEx échouera sur le Z Flip6.

Le test matériel reste nécessaire. Le script vérifie le processus serveur mais seul FlipEx peut confirmer son propre Binder et son UserService.

## Procédure sur le matériel réel

Sur le Chromebook :

```bash
cd ~/FlipdexOS
git pull --ff-only origin main
bash scripts/diagnose-flipex-android.sh --output ~/flipex-android-report.txt
bash scripts/flipex-monitor.sh --check
bash scripts/flipex-monitor.sh
```

Sur le Z Flip6, ouvrir Shizuku, démarrer le serveur en mode ADB, vérifier son état « en cours d'exécution », puis vérifier que FlipEx est autorisé. Tester le bureau, les clics, la saisie clavier, le redimensionnement de la fenêtre et la fermeture de scrcpy. Pour tester le redimensionnement adaptatif volontaire, relancer avec `--flex-display`.

En cas d'arrêt anormal, revenir sur le Chromebook et exécuter `flipex-monitor --restore`.

## Sources techniques

- [scrcpy — documentation des écrans virtuels](https://github.com/Genymobile/scrcpy/blob/master/doc/virtual-display.md) : `--new-display`, `--flex-display` et conservation du contenu lors de la fermeture.
- [scrcpy — dépôt officiel](https://github.com/Genymobile/scrcpy/) : version et options disponibles.
- [Shizuku API — documentation UserService et Binder](https://github.com/RikkaApps/Shizuku-API/blob/master/README.md) : le service utilisateur est distinct du processus Android classique.
- [Shizuku — implémentation de pingBinder()](https://github.com/RikkaApps/Shizuku-API/blob/master/api/src/main/java/rikka/shizuku/Shizuku.java).
- [Shizuku issue #2681 — One UI 9 / Android 17](https://github.com/RikkaApps/Shizuku/issues/2681).

## Verdict de l'étape 3

**Côté FlipdexOS :** contrôles Shizuku, gestion sûre des réglages, comportement de résolution et tests automatisés sont intégrés.

**Côté matériel :** validation réelle sur le Lenovo Duet et le Z Flip6 encore à effectuer.

**Côté application Android FlipEx :** aucun fichier upstream ni APK Android n'a été modifié à cette étape.
