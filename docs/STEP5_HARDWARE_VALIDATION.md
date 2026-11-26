# FlipdexOS — Étape 5/5 : validation finale sur matériel

Date : 2026-11-26

Cette étape clôt le travail logiciel de la version alpha candidate. Les tests CI et les builds sont automatisés ; les essais sur Z Flip6 et Chromebook restent à exécuter sur les appareils physiques. Ne pas marquer ces tests matériels comme réussis avant observation.

## Cibles
- Samsung Galaxy Z Flip6 (Android 17 / One UI 9) : APK `io.github.yoyote84.flipdexos`.
- Lenovo Chromebook Duet ARM64 / MediaTek Helio P60T, postmarketOS + Plasma : bundle Flatpak ARM64.

## 1 — Installation APK sur le Z Flip6
1. Télécharger l'artefact APK de la CI (ou le fichier APK distribué par le projet).
2. Vérifier son SHA-256 avec le fichier .sha256 fourni.
3. Installer l'APK. Si Android refuse une mise à jour à cause d'une signature différente, ne pas désinstaller une version dont les données doivent être conservées ; vérifier la provenance et la signature avant de procéder.
4. Ouvrir FlipdexOS. Vérifier que le panneau compagnon s'affiche, que le téléphone reste utilisable et qu'aucune permission non demandée n'est sollicitée.
5. Fermer puis rouvrir l'application et vérifier l'absence de crash.

## 2 — Shizuku (facultatif)
1. Démarrer Shizuku selon sa procédure officielle via ADB.
2. Dans FlipdexOS, sélectionner le bouton de connexion/détection Shizuku.
3. Autoriser l'accès seulement si la demande provient de FlipdexOS.
4. Vérifier que le diagnostic indique UID shell (2000) et des résultats cohérents.
5. Refuser la permission puis vérifier que l'application reste fonctionnelle et explique l'état ; Shizuku n'est pas requis pour lancer la session scrcpy.
6. Ne pas modifier des paramètres système hors des contrôles explicitement autorisés.

## 3 — Préparer le Chromebook
Prérequis sur l'hôte : ADB, scrcpy, Flatpak. Installer scrcpy depuis la source officielle Genymobile et préférer la version stable 5.0.1 ou plus récente si disponible et validée.

Vérifier :
```bash
adb version
scrcpy --version
flatpak --version
```

Installer le bundle :
```bash
flatpak install --user --bundle ./FlipdexOS-Chromebook-aarch64.flatpak
flatpak run io.github.yoyote84.flipdexos
```

Le runtime Freedesktop 26.08 est nécessaire. Le bundle s'appuie sur les outils ADB et scrcpy du système hôte.

## 4 — Connexion USB et bureau virtuel
1. Connecter le Z Flip6 au Chromebook via USB-C.
2. Sur le téléphone, accepter la demande de débogage USB et cocher « toujours autoriser » uniquement pour le Chromebook de confiance.
3. Sur le Chromebook, vérifier : `adb devices`. L'état doit être `device`, et non `unauthorized`.
4. Lancer FlipdexOS Monitor.
5. Vérifier la création de l'affichage virtuel et l'ouverture de FlipdexOS dans celui-ci.
6. Confirmer que l'écran principal du téléphone reste indépendant et utilisable.
7. Tester souris, pavé tactile, clavier, saisie AZERTY et clics.
8. Tester recherche et lancement de plusieurs applications. Certaines applications peuvent être incompatibles avec les displays secondaires.
9. Fermer la session, débrancher/rebrancher et relancer.

## 5 — Tests de stabilité et récupération
- [ ] Connexion USB répétée sans redémarrage des appareils.
- [ ] Déconnexion câble en cours de session : l'application explique ou récupère proprement.
- [ ] Fermeture du client : aucune session/affichage résiduel non souhaité.
- [ ] Redémarrage Android : fonctionnement normal de l'écran principal.
- [ ] Redémarrage Plasma : le client est relançable.
- [ ] Mode ADB non autorisé : message d'erreur compréhensible.
- [ ] Shizuku absent : la session de bureau ADB reste possible.
- [ ] Test de résolution, FPS et bitrate modestes pour vérifier la stabilité sur ARM64.
- [ ] Vérifier que les paramètres restaurés ne sont pas modifiés par défaut ; utiliser `--restore` seulement après avoir consulté le snapshot.

## 6 — Checklist résultat
- [ ] APK installée et panneau companion fonctionnel sur Z Flip6.
- [ ] Shizuku (si utilisé) diagnostiqué.
- [ ] ADB USB reconnu sur Chromebook.
- [ ] Flatpak installé et lancé sous Plasma.
- [ ] Display virtuel visible.
- [ ] Écran principal du téléphone indépendant.
- [ ] Applications lancées sur le display virtuel.
- [ ] Souris/clavier vérifiés.
- [ ] Fermeture et récupération vérifiées.

Consigner les résultats, versions Android/One UI, version scrcpy, résolution et erreurs avant de déclarer l'étape matérielle terminée.

## Sécurité et limites
- APK CI : version debug, pas une release signée avec une clé de distribution personnelle.
- Shizuku : permission facultative ; ne pas accorder à un APK non vérifié.
- ADB : désactiver le débogage USB ou révoquer les autorisations sur les appareils non fiables après les essais.
- Flatpak : le proxy `flatpak-spawn --host` et ses permissions peuvent être sensibles ; paquet destiné à un usage local maîtrisé, pas une publication Flathub sans revue de sécurité.
- Android multi-display dépend de l'appareil et des applications. La prise en charge n'est pas universelle.
- Aucun essai physique n'est revendiqué par ce document.
