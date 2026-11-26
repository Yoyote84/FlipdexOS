# FlipdexOS — FlipEx Monitor

Client Linux ARM64 pour ouvrir le bureau virtuel de **FlipEx** dans une fenêtre du Chromebook et le piloter avec le pavé tactile et le clavier du Chromebook.

> **État : version interactive en cours de validation matérielle.** Le lanceur, l'entrée souris/clavier, l'installation dans le menu et les tests simulés sont présents. Le fonctionnement exact avec le Lenovo Duet et le Samsung Z Flip 6 doit encore être confirmé sur les appareils réels. Aucun paquet ARM64 précompilé n'est publié.

## Ce que fait FlipEx Monitor

1. Le Chromebook se connecte au Z Flip 6 par USB et ADB.
2. Le lanceur démarre l'application Android FlipEx.
3. scrcpy ouvre un **nouvel écran virtuel** Android dans une fenêtre Linux : ce n'est pas le miroir de l'écran principal du téléphone.
4. Le pavé tactile et le clavier du Chromebook contrôlent le bureau affiché.
5. Le téléphone conserve son écran principal et peut rester utilisable indépendamment.

Le contrôle est actif : **ne pas ajouter `--no-control`**, car cette option désactive les entrées souris et clavier.

## Commande depuis le menu du Chromebook

Après installation, ouvre **FlipEx Monitor — Connexion** depuis le menu des applications. Le lanceur choisit automatiquement l'unique téléphone ADB autorisé et démarre FlipEx puis le bureau virtuel. Le lanceur de menu ne demande pas d'ouvrir un terminal.

En cas d'erreur, une notification du bureau est affichée lorsque `notify-send` ou `kdialog` est disponible. Une notification indique également que le téléphone est connecté et que le bureau s'ouvre.

**Première autorisation USB :** Android impose d'accepter l'empreinte de débogage USB sur le Z Flip 6. Branche le téléphone, déverrouille-le et accepte la demande Android (tu peux cocher « Toujours autoriser depuis cet ordinateur »). FlipdexOS ne peut pas accepter cette autorisation à la place de l'utilisateur. Le débogage USB doit rester activé.

## Souris et clavier

### Souris — mode par défaut `sdk`

Le mode par défaut transmet les événements de souris à Android par son API, avec des coordonnées absolues. Le curseur reste géré par le Chromebook : il n'est pas capturé et il n'est pas nécessaire d'appuyer sur Alt pour le récupérer.

Les clics secondaires sont explicitement transmis à Android au lieu d'être convertis en raccourcis Retour / Accueil / notifications. Le comportement précis du clic droit, du glisser-déposer et de la molette dépend aussi de la façon dont One UI et les applications Android gèrent les événements de souris.

Pour utiliser une véritable souris HID Android à la place :

```bash
flipex-monitor --mouse uhid
```

Le mode `uhid` simule une souris physique. scrcpy capture alors le pointeur du Chromebook ; **Alt gauche** libère ou reprend la capture. C'est pourquoi ce mode n'est pas le réglage par défaut.

### Clavier — mode par défaut `uhid`

Le clavier du Chromebook est transmis comme un clavier physique Android. Configure une seule fois le clavier physique du téléphone en Français (AZERTY) dans les paramètres Android.

Pour tester l'autre mode clavier :

```bash
flipex-monitor --keyboard sdk
```

## Écran virtuel et écran overlay facultatif

Le réglage par défaut est :

- `--display-mode virtual` : demande directement un nouvel écran virtuel à scrcpy. C'est le chemin normal ; il évite le détour par un écran overlay de test.
- `--display-mode overlay` : utilise à la place un écran secondaire overlay créé dans les paramètres Android. C'est une solution de repli à essayer uniquement si l'écran virtuel standard ne convient pas sur un appareil donné.

L'overlay est facultatif et n'est **pas choisi automatiquement** sur Android 17. Quand le mode overlay est utilisé, le script mémorise la valeur précédente de `overlay_display_devices` et la restaure à la fermeture de scrcpy.

## Profil haute netteté pour le Lenovo Duet

Les réglages par défaut limitent la charge graphique et la latence :

- 1920 × 1080 à 30 images/s ;
- H.264 lorsque pris en charge ;
- densité virtuelle 240 DPI ;\n- débit vidéo de 12 Mbit/s ;
- tampon vidéo minimal lorsque pris en charge ;
- audio désactivé.

Pour une image plus détaillée :

```bash
flipex-monitor --display 1920x1080/240 --fps 30 --bit-rate 12M
```

Pour privilégier la fluidité :

```bash
flipex-monitor --display 1280x720/160 --fps 25 --bit-rate 3M
```

## Prérequis

Sur le Z Flip 6 :

1. Installer et configurer l'application Android [FlipEx](https://github.com/Vedjamkar/flipex).
2. Activer les options développeur et le débogage USB.
3. Déverrouiller le téléphone et autoriser l'ordinateur ADB.

Sur le Chromebook Linux (Debian/Ubuntu ARM64) :

```bash
sudo apt update
sudo apt install adb scrcpy bash
```

Une version de scrcpy proposant `--new-display`, `--mouse` et `--keyboard` est nécessaire. Le lanceur vérifie les options disponibles au démarrage et affiche une erreur si elles manquent. `libnotify-bin` ou `kdialog` est facultatif pour les notifications de bureau.

Le Chromebook doit disposer d'une session graphique Linux (Wayland ou X11). Le câble USB-C transporte ici ADB et le flux vidéo compressé ; il ne transforme pas le Chromebook en moniteur HDMI natif.

## Installation

Depuis la racine du dépôt :

```bash
chmod +x scripts/flipex-monitor.sh scripts/install-system.sh
./scripts/flipex-monitor.sh --check
./scripts/flipex-monitor.sh --list
bash scripts/install-system.sh
```

Le script d'installation place `flipex-monitor` dans `/usr/local/bin` et l'entrée de menu dans `/usr/share/applications`. Il utilise `sudo` si nécessaire. Ouvre ensuite **FlipEx Monitor — Connexion** dans le menu.

## Options pratiques

```bash
flipex-monitor --help
flipex-monitor --check
flipex-monitor --list
flipex-monitor --display 1600x900/160 --fps 30 --bit-rate 6M
flipex-monitor --mouse uhid
flipex-monitor --display-mode overlay
flipex-monitor --restore
```

Si plusieurs appareils ADB sont connectés :

```bash
flipex-monitor --serial NUMERO_ADB
```

La commande de restauration remet à zéro les trois réglages du mode bureau gérés par le lanceur et supprime le réglage overlay. Elle ne désinstalle pas FlipEx. Pour restaurer aussi les réglages propres à FlipEx, utiliser **Restore stock settings** dans l'application Android.

## Tests et développement

Depuis la racine du dépôt :

```bash
bash -n scripts/flipex-monitor.sh
bash -n scripts/install-system.sh
bash tests/fake-tools.sh
```

Le test simulé vérifie le mode écran virtuel + souris SDK par défaut, le mode souris HID optionnel et la restauration de l'overlay. Il ne remplace pas un essai sur le Z Flip 6 réel.

## Références techniques

- [Projet FlipEx Android et client de bureau](https://github.com/Vedjamkar/flipex)
- [Documentation scrcpy — souris](https://github.com/Genymobile/scrcpy/blob/master/doc/mouse.md)
- [Documentation scrcpy — clavier](https://github.com/Genymobile/scrcpy/blob/master/doc/keyboard.md)
- [Options scrcpy](https://github.com/Genymobile/scrcpy/blob/master/app/scrcpy.1)

FlipdexOS Monitor est un projet indépendant et n'est ni développé, ni approuvé par Samsung ou par les auteurs de FlipEx.
