# FlipdexOS — étape 5/5 : finalisation et validation

Date : 26 novembre 2026

## Cibles livrées

- **Téléphone :** Samsung Galaxy Z Flip6, Android 17 / API 37, One UI 9.
- **Chromebook :** Lenovo Chromebook Duet, MediaTek Helio P60T, postmarketOS / Alpine, Plasma Desktop, ARM64.

Le produit comporte deux paquets différents : APK Android installée sur le téléphone et Flatpak ARM64 installé sur le Chromebook.

## Clôture automatisée confirmée

Sur le commit de livraison précédent (`f1da4cf2820c2523e1d08f1c8b8e0c2630d82a46`), GitHub Actions a terminé avec succès :

| Pipeline | Résultat |
|---|---|
| Tests généraux #151 | Réussis |
| Compilation APK debug #46 | Réussie |
| Compilation Flatpak ARM64 #54 | Réussie |

L'APK debug a été produite, signée par la clé debug temporaire du runner et son SHA-256 a été vérifié. Le bundle Flatpak ARM64 a été créé par la CI native ARM64. Ces contrôles ne testent pas le téléphone ou le Chromebook physiques.

## Corrections de finalisation

### Shizuku n'est plus un bloqueur du bureau

Le client Linux avait rendu obligatoire la présence et le démarrage de Shizuku. Ce prérequis était trop strict : la session bureau externe utilise déjà ADB shell pour sauvegarder/restaurer les paramètres et scrcpy pour ouvrir le bureau virtuel. Shizuku reste nécessaire aux diagnostics privilégiés dans l'application Android, mais il n'est plus obligatoire pour lancer le bureau depuis le Chromebook.

Ce changement évite de bloquer toute la session en cas de dysfonctionnement Shizuku. Des rapports ouverts décrivent des problèmes Shizuku sous One UI 9 / Android 17 ; ils concernent plusieurs modèles Samsung et ne prouvent pas à eux seuls le comportement exact du Z Flip6.

### Cycle de vie de l'interface Android

Les callbacks de réception et de mort du Binder Shizuku sont désormais redirigés vers le thread principal et ignorés lorsque l'activité est détruite. Cela évite les mises à jour de TextViews depuis un thread Binder et les callbacks tardifs.

### Version et signature

Le code Android passe à `versionCode 2` / `0.1.0-alpha02`. L'APK de test demeure une variante debug. Le dépôt contient désormais une procédure de signature durable et un workflow manuel release qui exige une clé privée contrôlée par le propriétaire, sans jamais la stocker dans Git.

## Pourquoi targetSdk reste à 36

L'application compile avec `compileSdk 37` et AGP 9.4.0 / Gradle 9.6.0 / JDK 17. Le niveau d'exécution demeure `targetSdk 36` jusqu'à la validation du mode multi-écran sur le Z Flip6. Android 17 change le traitement des restrictions d'orientation et de redimensionnement pour les applications ciblant API 37 ou plus, notamment sur les grands écrans. Il serait prématuré d'activer ce changement de comportement sans test matériel.

## Procédure de validation sur le Z Flip6

1. Installer l'APK debug depuis l'artefact `flipdexos-android-debug-apk`.
2. Ouvrir l'application sur l'écran principal et vérifier le panneau compagnon.
3. Démarrer Shizuku, autoriser FlipdexOS et demander le diagnostic. Le résultat attendu si le service fonctionne en mode ADB est l'UID 2000.
4. Appuyer sur l'aperçu du bureau ; vérifier la recherche et l'ouverture de quelques applications.
5. Ne pas modifier manuellement les trois paramètres du mode bureau pendant la session de test.

Si une ancienne APK debug installée avec une autre clé empêche la mise à jour, désinstaller `io.github.yoyote84.flipdexos` avant de réinstaller la nouvelle APK. Cela efface les données privées de l'application.

## Procédure de validation sur le Chromebook

1. Installer Flatpak et les outils hôte ADB / scrcpy sur postmarketOS.
2. Installer le bundle `flipdexos-monitor-aarch64.flatpak`.
3. Brancher et déverrouiller le Z Flip6, activer le débogage USB et accepter l'empreinte RSA ADB.
4. Lancer FlipdexOS Monitor depuis le menu Plasma.
5. Vérifier que scrcpy crée un écran virtuel, que FlipdexOS Desktop y apparaît et que l'écran principal du téléphone reste utilisable.
6. Tester souris SDK, clavier physique, résolution fixe, puis fermer scrcpy et vérifier la restauration des trois paramètres.
7. Faire un second test avec Shizuku arrêté : la session Chromebook doit continuer et afficher un avertissement non bloquant.

Commande de récupération après arrêt brutal :
```bash
flipex-monitor --restore
```

## Matrice de statut

| Vérification | État |
|---|---|
| Build APK debug et signature debug | Réussi en CI sur commit de livraison précédent |
| Tests logiques Android | Réussis en CI sur commit précédent |
| Build Flatpak ARM64 | Réussi en CI sur commit précédent |
| Tests simulés ADB, résolution, souris et clavier | Réussis en CI sur commit précédent |
| Session avec Shizuku absent ou arrêté | Nouvelle correction et tests CI à exécuter sur ce commit |
| Installation sur Z Flip6 réel | À effectuer par l'utilisateur |
| Session USB / Plasma sur Lenovo Duet réel | À effectuer par l'utilisateur |
| Signature release durable | Prête ; nécessite le keystore privé du propriétaire |

## Conclusion

Le code, les deux formats de paquets et les pipelines automatisés sont en place. L'acceptation finale sur matériel n'est pas certifiable depuis GitHub Actions : elle nécessite les deux appareils physiques. L'APK debug est adaptée au premier essai ; une APK release durable sera générée dès que les secrets de signature du propriétaire seront configurés.

## Références techniques

- Android 17 — SDK : https://developer.android.com/about/versions/17/setup-sdk
- Android 17 — changements de comportement pour target API 37 : https://developer.android.com/about/versions/17/behavior-changes-17
- AGP 9.4.0 — API 37 / Gradle 9.6.0 / JDK 17 : https://developer.android.com/build/releases/agp-9-4-0-release-notes
- Shizuku — problème One UI 9 : https://github.com/RikkaApps/Shizuku/issues/2681
- Shizuku-API — guide UserService : https://github.com/RikkaApps/Shizuku-API
- scrcpy — écran virtuel et lancement d'application : https://github.com/Genymobile/scrcpy/blob/master/doc/virtual-display.md
- Android — signature de publication : https://developer.android.com/build/build-for-release
