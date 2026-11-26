# Application Android FlipdexOS — architecture initiale

Date : 2026-11-26

## Objectif matériel

L'APK est destinée au Samsung Galaxy Z Flip6 sous Android 17 / One UI 9. Le client Linux/Flatpak reste destiné au Lenovo Chromebook Duet ARM64 sous postmarketOS et Plasma.

Le comportement recherché est un bureau sur un **écran virtuel secondaire**, affiché dans une fenêtre sur le Chromebook. L'écran principal du Z Flip6 doit continuer à fonctionner indépendamment.

## Conception

### Application compagnon sur le téléphone

`MainActivity` fournit l'état de l'appareil, l'état réel du Binder Shizuku et un diagnostic du UserService. Elle ne modifie pas les paramètres globaux à son ouverture. Le UserService est facultatif pour le bureau externe : le client Chromebook utilise l'identité ADB shell pour ses paramètres et sa session scrcpy.

Le UserService expose une interface AIDL limitée :
- lecture de quatre propriétés système connues ;
- lecture de trois réglages globaux précisément autorisés ;
- écriture uniquement des valeurs `0` et `1` pour ces trois réglages ;
- suppression de ces mêmes réglages ;
- lecture de l'identité UID pour vérifier que le service s'exécute comme shell (UID 2000 avec Shizuku démarré par ADB).

Aucune méthode ne permet d'exécuter une commande arbitraire ni de passer du texte utilisateur dans un shell.

### Bureau secondaire

`DesktopActivity` est une activité Android redimensionnable, exportée pour le lancement explicite par scrcpy. Elle :
- affiche le numéro de l'écran sur lequel elle a été lancée ;
- répertorie les applications déclarées comme lanceurs par Android ;
- filtre la liste par nom ou identifiant de paquet ;
- lance une application sur le même écran grâce à `ActivityOptions.setLaunchDisplayId()`.

Le client Linux demande à scrcpy de créer un nouvel écran et de démarrer le paquet FlipdexOS via `--start-app` (cette option attend un nom de paquet, pas un nom d'activité). `MainActivity` détecte un lancement MAIN/LAUNCHER sur un écran non principal, démarre `DesktopActivity` sur ce même écran puis se ferme. Sur l'écran principal, le même paquet ouvre normalement le panneau compagnon.

## API et limites

L'application compile contre Android 17 / API 37, mais cible provisoirement API 36. Le passage à `targetSdk 37` est réservé à la phase de validation des changements de comportement d'Android 17.

La création/capture de l'écran virtuel reste du ressort de scrcpy lancé sur le Chromebook. L'API Android publique `DisplayManager.createVirtualDisplay()` crée un affichage dont la surface appartient à l'application ; elle ne constitue pas à elle seule un moyen public de créer un bureau système complet et contrôlable depuis l'extérieur.

Le routage d'une application vers un affichage secondaire dépend aussi des règles Android, de sa prise en charge multi-écran et des décisions du constructeur Samsung. Certaines applications peuvent refuser de s'ouvrir sur cet écran.

## Licence

Le code original de l'application est MIT. Les avis des composants et projets consultés sont dans [app/THIRD_PARTY_NOTICES.md](../app/THIRD_PARTY_NOTICES.md). Le code FlipEx sans licence n'est pas repris.
