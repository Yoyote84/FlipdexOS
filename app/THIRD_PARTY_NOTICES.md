# Notices — application Android FlipdexOS

Le code original du module Android FlipdexOS est publié sous licence MIT
(voir [LICENSE](LICENSE)).

## Dépendance incluse dans l'APK

### Shizuku API / Provider 13.1.5
- Projet : https://github.com/RikkaApps/Shizuku-API
- Licence : MIT
- Notice : Copyright (c) 2021 RikkaW
- Usage : API cliente Binder et UserService pour les opérations explicitement autorisées.

La licence MIT autorise l'utilisation, la modification et la redistribution en
conservant la notice de copyright et le texte de licence. Aucun fichier source
de Shizuku-API n'est recopié : la dépendance est résolue par Maven.

## Outil du client Linux (non embarqué dans l'APK)

### scrcpy 5.0.1 ou version ultérieure
- Projet : https://github.com/Genymobile/scrcpy
- Licence : Apache-2.0
- Usage : création et capture de l'écran virtuel Android depuis le Chromebook.
- Le code scrcpy n'est pas incorporé à l'APK Android.

## Projets consultés uniquement comme références de conception

### android-desk
- Projet : https://github.com/jitunayak/android-desk
- Licence : GPL-3.0
- Usage : référence fonctionnelle pour l'écran virtuel, le lanceur et le routage des applications.
- Aucun fichier source n'est copié dans FlipdexOS.

### FlipEx
- Projet : https://github.com/Vedjamkar/flipex
- Aucune licence de réutilisation déclarée dans les métadonnées GitHub au moment de l'audit.
- Usage : compréhension des fonctions attendues seulement.
- Aucun code source FlipEx n'est copié dans FlipdexOS.
