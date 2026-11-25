# FlipdexOS — FlipEx Monitor

Client Linux ARM64 pour afficher **le bureau DeX virtuel** de FlipEx dans une fenêtre du Chromebook, tout en utilisant la souris et le clavier du Chromebook pour piloter Android.

> **État : portage en cours, première version interactive.** Le lanceur, les modes d'affichage et les tests automatisés sont présents. Le fonctionnement avec le Lenovo Duet et le Z Flip 6 doit encore être confirmé sur le matériel réel. Aucun paquet ARM64 précompilé n'est publié.

## Fonctionnement

- Connexion USB-C et ADB entre le Z Flip 6 et le Chromebook.
- FlipEx prépare le mode bureau Android.
- scrcpy affiche un second écran Android, pas le miroir de l'écran principal.
- La souris et le clavier du Chromebook sont transmis au bureau DeX.
- Le téléphone reste utilisable indépendamment.

Le mode par défaut est interactif : **ne pas ajouter `--no-control`**, car cela désactive volontairement la souris et le clavier distants.

## Réglages optimisés pour le Lenovo Duet

Le profil initial limite la charge graphique et la latence :

- 1280 × 720 à 30 images/s ;
- H.264 ;
- débit vidéo 4 Mbit/s ;
- tampon vidéo à 0 ms lorsqu'il est disponible ;
- audio désactivé ;
- maintien actif de l'écran lorsque la version de scrcpy le prend en charge.

Pour privilégier la netteté, tu peux monter à 1600 × 900 et 6 Mbit/s :

```bash
./scripts/flipex-monitor.sh --display 1600x900/160 --fps 30 --bit-rate 6M
```

## Prérequis

Sur le Z Flip 6 :

1. Installer et configurer l'application Android officielle [FlipEx](https://github.com/Vedjamkar/flipex).
2. Activer les options développeur et le débogage USB.
3. Déverrouiller le téléphone, brancher le câble USB-C et accepter l'empreinte ADB.

Sur le Chromebook Linux (Debian/Ubuntu ARM64) :

```bash
sudo apt update
sudo apt install adb scrcpy bash
```

Le Chromebook doit disposer d'une session graphique Linux (Wayland ou X11) pour ouvrir scrcpy. Le câble USB-C transporte ici ADB et la vidéo compressée, pas une entrée HDMI native.

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

Ensuite ouvre **FlipEx Monitor** depuis le menu ou lance `flipex-monitor` dans un terminal.

Si plusieurs appareils ADB sont présents :

```bash
./scripts/flipex-monitor.sh --serial NUMERO_ADB
```

## Souris et clavier du Chromebook

Le mode par défaut utilise de vrais périphériques HID Android :

- `--mouse=uhid` : DeX reçoit une vraie souris. C'est le mode recommandé pour les barres de titre, le déplacement et le redimensionnement des fenêtres.
- `--keyboard=uhid` : DeX reçoit un vrai clavier physique, avec les caractères correspondant à la disposition configurée sur le téléphone.

**Pointeur capturé :** en mode UHID, scrcpy capture le pointeur quand sa fenêtre est active. Appuie sur **Alt gauche** pour rendre la souris au Chromebook ; clique à nouveau dans DeX pour la reprendre.

**Clavier AZERTY :** configure une seule fois le clavier physique Android en Français (AZERTY) dans Paramètres → Gestion globale / Système → Clavier physique. La page peut aussi être ouverte avec :

```bash
adb shell am start -a android.settings.HARD_KEYBOARD_SETTINGS
```

Si les clics ne répondent toujours pas sur le téléphone, certaines versions Android exigent l'option développeur **USB debugging (Security settings) / Allow granting permissions and simulating input via USB debugging**, puis un redémarrage.

### Alternative : pointeur sans capture

Pour essayer le mode souris SDK, où le pointeur est dessiné par le Chromebook et reste plus fluide à l'écran :

```bash
./scripts/flipex-monitor.sh --mouse sdk
```

Sur les versions récentes de One UI, le mode SDK peut être moins adapté aux barres de titre DeX : certains clics sont interprétés comme des gestes tactiles. Reviens à `--mouse uhid` pour déplacer et redimensionner les fenêtres.

## Android 17 / API 37 : mode d'écran automatique

Sur Android 17 / API 37+, le lanceur choisit par défaut un **écran overlay Android** et le scrcpy par `--display-id`. Ce contournement vise le changement de comportement des fenêtres de bureau sur les nouveaux écrans virtuels standards : l'écran overlay est présenté à Android comme un affichage secondaire externe.

- `--display-mode auto` : recommandé ; choisit overlay sur API 37+ et nouvel écran virtuel sur les versions plus anciennes.
- `--display-mode virtual` : force le nouvel écran virtuel scrcpy.
- `--display-mode overlay` : force l'écran overlay.

L'overlay peut afficher une petite prévisualisation de DeX sur l'écran du téléphone. Sa résolution est fixe pendant la session. Le lanceur mémorise la valeur précédente de `overlay_display_devices` et la restaure à la fermeture normale de scrcpy.

## Réduire encore les saccades

Utilise d'abord le câble USB, garde le téléphone déverrouillé et laisse son écran allumé. Puis :

```bash
./scripts/flipex-monitor.sh --display 1280x720/160 --fps 25 --bit-rate 3M
```

Évite le Wi-Fi pour le premier diagnostic. Si l'image est fluide mais que le pointeur semble lent, teste `--mouse sdk`. Si le pointeur est fluide mais que les fenêtres ne se déplacent pas correctement, reviens à `--mouse uhid`.

## Restaurer les réglages Android

```bash
./scripts/flipex-monitor.sh --restore
```

Cette commande remet à 0 les trois réglages du mode bureau gérés par le lanceur et supprime `overlay_display_devices`. Elle ne désinstalle pas FlipEx. Pour restaurer aussi les réglages propres à FlipEx, utiliser **Restore stock settings** dans l'application Android.

## Limites connues

- Le couple Lenovo Duet ARM64 / Samsung Z Flip 6 Android 17 n'a pas encore été revalidé après l'activation du contrôle HID.
- L'écran overlay dépend du comportement One UI / Android et peut ne pas être nécessaire sur les versions antérieures à Android 17.
- Le flux vidéo dépend du décodeur scrcpy disponible sur la session Linux du Chromebook ; la baisse de résolution réduit la charge, mais ne peut pas garantir une fluidité parfaite sur tous les pilotes graphiques.
- Pas encore de paquet .deb/AppImage ARM64 ; le lanceur utilise les paquets ADB et scrcpy de la distribution.

## Tests et développement

```bash
bash -n scripts/flipex-monitor.sh
bash -n scripts/install-system.sh
shellcheck scripts/flipex-monitor.sh scripts/install-system.sh
bash tests/fake-tools.sh
```

GitHub Actions exécute ces contrôles avec des outils Android simulés, notamment les chemins d'affichage Android 16 et Android 17.

## Références techniques

- [Projet FlipEx Android et client de bureau](https://github.com/Vedjamkar/flipex)
- [Documentation scrcpy — souris HID](https://github.com/Genymobile/scrcpy/blob/master/doc/mouse.md)
- [Documentation scrcpy — clavier HID](https://github.com/Genymobile/scrcpy/blob/master/doc/keyboard.md)
- [Documentation scrcpy — vidéo et qualité](https://github.com/Genymobile/scrcpy/blob/master/doc/video.md)
- [Options scrcpy](https://github.com/Genymobile/scrcpy/blob/master/app/scrcpy.1)
- [Référence technique récente : dex-script](https://github.com/ErenKaynak/dex-script)

FlipdexOS Monitor est un projet indépendant et n'est ni développé, ni approuvé par Samsung ou par les auteurs de FlipEx.
