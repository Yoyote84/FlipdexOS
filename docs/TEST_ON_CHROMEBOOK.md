# Premier test sur le Lenovo Duet

Ce document permet de vérifier le portage sans confondre le miroir de l'écran principal avec l'écran DeX virtuel.

## 1. Identifier l'environnement

Dans le terminal Linux du Chromebook :

```bash
uname -m
cat /etc/os-release
```

L'architecture attendue est `aarch64` ou `arm64`. Le système doit disposer d'une session graphique Linux pour afficher la fenêtre scrcpy.

## 2. Installer les outils

Sur Debian/Ubuntu ARM64 :

```bash
sudo apt update
sudo apt install adb scrcpy bash
```

Vérifier les options indispensables :

```bash
scrcpy --help | grep -E -- '--new-display|--no-control|--no-vd-destroy-content'
adb version
scrcpy --version
```

La version de scrcpy doit proposer les trois options. Le lanceur s'arrête sans démarrer de session si elles manquent.

## 3. Autoriser le Z Flip 6

Sur le téléphone :

1. Activer les Options pour les développeurs.
2. Activer le Débogage USB.
3. Brancher le téléphone en USB-C, le déverrouiller et accepter la clé RSA ADB.
4. Garder le téléphone déverrouillé pour ce premier essai.

Sur le Chromebook :

```bash
adb devices -l
```

L'appareil doit apparaître avec l'état `device`, et non `unauthorized`.

## 4. Lancer l'écran DeX virtuel

Depuis la racine du dépôt :

```bash
./scripts/flipex-monitor.sh --check
./scripts/flipex-monitor.sh --list
./scripts/flipex-monitor.sh
```

Le lanceur vérifie la présence de l'application Android FlipEx (`dev.ved.flipdex`), active les trois réglages globaux nécessaires, démarre FlipEx, puis ouvre scrcpy sur un nouvel écran virtuel de 1920 × 1080.

## 5. Vérifier le comportement demandé

- Le bureau DeX doit apparaître dans une fenêtre scrcpy séparée.
- L'écran principal du Z Flip doit rester utilisable indépendamment.
- Les clics, mouvements de souris et frappes clavier faits dans la fenêtre scrcpy ne doivent pas piloter le téléphone : le processus reçoit `--no-control`.
- Aucun flux audio n'est transféré par défaut.

Fermer la fenêtre scrcpy pour terminer l'affichage. Le paramètre `--no-vd-destroy-content` demande à Android de déplacer les applications de l'écran virtuel vers l'écran principal lors de sa fermeture.

## 6. Restaurer les réglages

Après l'essai :

```bash
./scripts/flipex-monitor.sh --restore
```

Cette commande remet à 0 les trois réglages globaux modifiés par le lanceur. Elle ne remplace pas la fonction **Restore stock settings** de l'application FlipEx pour ses propres réglages.

## Informations à relever en cas d'échec

Copier le résultat de ces commandes :

```bash
uname -a
cat /etc/os-release
adb devices -l
scrcpy --version
scrcpy --help | grep -E -- '--new-display|--no-control|--no-vd-destroy-content'
./scripts/flipex-monitor.sh --check
```

Puis préciser à quel moment le problème survient : détection USB, lancement FlipEx, création du nouvel écran, ou ouverture de la fenêtre vidéo.

Ne pas publier le numéro de série ADB ni les adresses IP privées dans un rapport public.
