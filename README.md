# FlipdexOS — FlipEx Monitor

Client Linux léger pour afficher le bureau DeX virtuel créé par FlipEx sur un Galaxy Z Flip, dans une fenêtre du Chromebook ou du PC.

> **État : première base de portage, à tester sur le matériel réel.** Le dépôt contient le lanceur de lecture seule et ses contrôles de base. Aucun paquet ARM64 précompilé n'est encore publié.

## Objectif

- Utiliser le câble USB-C et ADB pour détecter le Galaxy Z Flip.
- Demander à Android d'activer le mode bureau nécessaire à FlipEx.
- Créer un **écran virtuel secondaire** en 1920 × 1080, au lieu de recopier l'écran principal du téléphone.
- Afficher cet écran avec scrcpy.
- Garder le Chromebook en **lecture seule** : le lanceur passe explicitement `--no-control` à scrcpy et ne configure aucun transfert souris/clavier.

Le Chromebook sert uniquement d'écran. Les commandes ADB de préparation sont limitées aux réglages du mode bureau et au démarrage de l'application FlipEx sur le téléphone.

## Prérequis

Sur le téléphone :

1. Installer et configurer l'application Android officielle [FlipEx](https://github.com/Vedjamkar/flipex).
2. Activer les options développeur puis le débogage USB.
3. Déverrouiller le téléphone, brancher le câble USB-C et accepter l'empreinte ADB.

Sur le Chromebook Linux (Debian/Ubuntu ARM64) :

```bash
sudo apt update
sudo apt install adb scrcpy bash
```

Le Chromebook doit disposer d'une session graphique Linux (Wayland ou X11) pour ouvrir la fenêtre scrcpy. Ce projet ne transforme pas le port USB-C du Chromebook en entrée vidéo HDMI.

## Démarrage

Depuis la racine du dépôt :

```bash
chmod +x scripts/flipex-monitor.sh
./scripts/flipex-monitor.sh --check
./scripts/flipex-monitor.sh --list
./scripts/flipex-monitor.sh
```

Pour installer le lanceur dans le menu des applications Debian :

```bash
bash scripts/install-system.sh
```

Ensuite ouvre **FlipEx Monitor (lecture seule)** dans le menu des applications, ou lance `flipex-monitor` dans un terminal.

Si plusieurs appareils ADB sont présents :

```bash
./scripts/flipex-monitor.sh --serial NUMERO_ADB
```

Le réglage vidéo peut être changé :

```bash
./scripts/flipex-monitor.sh --display 1920x1080/160 --fps 30 --bit-rate 8M
```

Fermer la fenêtre scrcpy ou faire Ctrl+C dans le terminal arrête la session. L'option `--no-vd-destroy-content` demande à Android de déplacer les applications ouvertes vers l'écran principal lorsque l'écran virtuel est fermé.

## Lecture seule : garantie côté scrcpy

Le lanceur utilise notamment :

- `--new-display=1920x1080/160`
- `--no-control`
- `--no-audio`
- `--no-clipboard-autosync`
- `--no-vd-destroy-content`

Il **n'ajoute pas** `--mouse`, `--keyboard`, `--mouse-bind` ou de raccourcis de contrôle. Avec `--no-control`, scrcpy désactive le contrôle de l'appareil et n'injecte pas les mouvements, clics ou frappes provenant du Chromebook.

## Rétablir les réglages Android

Le démarrage active trois réglages globaux Android utilisés par FlipEx. Pour les remettre à 0 :

```bash
./scripts/flipex-monitor.sh --restore
```

Cette commande ne désinstalle pas FlipEx. Elle remet à zéro les réglages du mode bureau gérés par ce lanceur. Pour restaurer aussi les paramètres propres à FlipEx, utiliser la fonction **Restore stock settings** de l'application Android.

## Connexion Wi-Fi (facultative)

La première association ADB sans fil se fait manuellement depuis les Options pour les développeurs → Débogage sans fil. Puis :

```bash
adb pair IP:PORT CODE
adb connect IP:PORT
./scripts/flipex-monitor.sh
```

Le câble USB reste le chemin recommandé pour le premier test.

## Limites connues

- Le portage n'a pas encore été exécuté sur le Lenovo Duet ARM64 : compatibilité du paquet scrcpy, des permissions USB et du serveur graphique à confirmer.
- L'écran DeX virtuel dépend de FlipEx, de la version Android/One UI et du comportement du téléphone. Le lanceur ne peut pas ajouter DeX à un modèle ou à une version qui ne le prend pas en charge.
- Le flux vidéo apparaît dans la fenêtre scrcpy. Le lanceur ne réimplémente pas le décodeur vidéo.
- Pas encore de paquet .deb/.AppImage publié ; le script utilise les paquets ADB et scrcpy du système.
- Le mode lecture seule concerne le flux scrcpy. L'ADB reste une liaison de préparation technique et peut modifier les paramètres explicitement décrits ci-dessus.

## Développement

Vérification locale :

```bash
bash -n scripts/flipex-monitor.sh
shellcheck scripts/flipex-monitor.sh
```

Les contrôles automatisés sont définis dans [GitHub Actions](.github/workflows/checks.yml).

## Références techniques

- [Projet FlipEx Android et client de bureau](https://github.com/Vedjamkar/flipex)
- [Code du client de bureau FlipEx](https://github.com/Vedjamkar/flipex/tree/main/desktop)
- [Documentation scrcpy](https://github.com/Genymobile/scrcpy)
- [Options scrcpy : nouvel écran et lecture seule](https://github.com/Genymobile/scrcpy/blob/master/app/scrcpy.1)
- [Prérequis Linux de Tauri](https://v2.tauri.app/start/prerequisites/)

FlipdexOS Monitor est un projet indépendant et n'est ni développé, ni approuvé par Samsung ou par les auteurs de FlipEx.
