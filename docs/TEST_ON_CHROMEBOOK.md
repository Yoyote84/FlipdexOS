# Test interactif sur le Lenovo Duet + Galaxy Z Flip 6

Cette procédure vérifie l'écran DeX secondaire et le contrôle depuis le Chromebook.

## 1. Préparer le Chromebook

Dans le terminal Linux :

```bash
uname -m
cat /etc/os-release
sudo apt update
sudo apt install adb scrcpy bash
```

L'architecture attendue est `aarch64` ou `arm64`. Il faut une session graphique Linux pour afficher scrcpy.

Vérifie que la version de scrcpy expose les options principales :

```bash
scrcpy --help | grep -E -- '--new-display|--display-id|--mouse|--keyboard|--video-buffer'
adb version
scrcpy --version
```

## 2. Préparer le téléphone

1. Active les Options pour les développeurs.
2. Active le Débogage USB.
3. Branche le téléphone en USB-C.
4. Déverrouille-le et accepte la clé RSA ADB.
5. Ouvre FlipEx sur le Z Flip 6 et vérifie qu'il est configuré.

Sur le Chromebook :

```bash
adb devices -l
```

Le Z Flip doit apparaître avec l'état `device`, pas `unauthorized`.

## 3. Lancer le bureau

Depuis la racine du dépôt :

```bash
bash scripts/flipex-monitor.sh --check
bash scripts/flipex-monitor.sh --list
bash scripts/flipex-monitor.sh
```

Le profil initial est 1280 × 720, 30 images/s et 4 Mbit/s. Le lanceur détecte le niveau d'API Android : nouvel écran virtuel sur les versions antérieures à Android 17, overlay sur API 37+.

## 4. Tester la souris du Chromebook

Le mode par défaut est `uhid`. Clique dans la fenêtre DeX : le pointeur du Chromebook doit être capturé et le pointeur Android doit se déplacer dans DeX.

- **Alt gauche** libère le pointeur pour le Chromebook.
- Clique à nouveau dans la fenêtre pour reprendre la souris.
- Teste clic gauche, clic droit, défilement et déplacement/redimensionnement d'une fenêtre DeX.

Pour essayer un pointeur toujours dessiné côté Chromebook :

```bash
bash scripts/flipex-monitor.sh --mouse sdk
```

Le mode SDK peut être plus fluide, mais peut mal gérer les barres de titre sur les versions récentes de One UI.

## 5. Tester le clavier du Chromebook

Le mode par défaut est `uhid`. Configure une fois la disposition physique du téléphone en **Français (AZERTY)** :

```bash
adb shell am start -a android.settings.HARD_KEYBOARD_SETTINGS
```

Clique dans une zone de texte DeX et saisis des lettres accentuées, chiffres et signes AZERTY. Le clavier virtuel Android est masqué sur l'écran DeX lorsque la version de scrcpy expose `--display-ime-policy=hide`.

Si Android refuse l'injection clavier/souris, certaines versions nécessitent l'option développeur **USB debugging (Security settings) / Allow granting permissions and simulating input via USB debugging**, puis un redémarrage.

## 6. Réduire les saccades

Utilise le câble USB et garde le téléphone déverrouillé et éveillé. Commence par le profil léger :

```bash
bash scripts/flipex-monitor.sh --display 1280x720/160 --fps 25 --bit-rate 3M
```

Pour une image plus nette, essaie :

```bash
bash scripts/flipex-monitor.sh --display 1600x900/160 --fps 30 --bit-rate 6M
```

Si le pointeur lag mais l'image est fluide, compare `--mouse sdk` et `--mouse uhid`. Si les fenêtres DeX ne peuvent pas être déplacées, repasse à `uhid`.

## 7. Fermer et restaurer

Ferme la fenêtre scrcpy pour arrêter le flux. En mode overlay, le lanceur restaure normalement la valeur précédente d'`overlay_display_devices` à la fermeture.

Pour remettre à 0 les trois réglages globaux de mode bureau :

```bash
bash scripts/flipex-monitor.sh --restore
```

## Rapport de test

En cas de problème, copie :

```bash
uname -a
cat /etc/os-release
adb devices -l
scrcpy --version
scrcpy --help | grep -E -- '--new-display|--display-id|--mouse|--keyboard|--video-buffer'
bash scripts/flipex-monitor.sh --check
```

Précise si le souci concerne la détection USB, l'image, le pointeur, le clavier, ou les fenêtres DeX. Ne publie pas le numéro de série ADB ni l'adresse IP privée.
