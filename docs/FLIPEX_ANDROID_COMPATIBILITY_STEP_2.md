# FlipEx Android — étape 2/5 : prévalidation Android 17

Date : 2026-11-26

## Résultat de l'étape

Cette étape ajoute à **FlipdexOS** un diagnostic reproductible et non destructif du téléphone Android connecté en ADB. Il contrôle les propriétés Android/One UI, l'installation des paquets Shizuku et FlipEx et le target SDK de l'APK installé. Des tests avec ADB simulé sont ajoutés à la CI.

**Cette étape ne modifie pas le code source non licencié de FlipEx et ne produit pas d'APK FlipEx.** Le dépôt upstream est public, mais GitHub ne déclare aucune licence (\`license: null\`) et le compte connecté ne dispose pas de droits d'écriture sur \`Vedjamkar/flipex\`. L'accès public au code n'autorise pas à le redistribuer ou publier une version dérivée.

## Corrections factuelles sur l'audit de l'étape 1

L'audit examinait le commit upstream \`6bfdeb9f779bf921e659baf614a08021bcb529ec\`, dont \`app/build.gradle\` déclare \`versionName '0.3.4'\`. Toutefois, la dernière release GitHub publiée retournée par l'API est **v0.3.0**. La source 0.3.4 est donc un état alpha du code, pas une release APK publiée sous ce numéro. La formulation « release v0.3.4-alpha » dans le rapport précédent était imprécise et doit être comprise comme « code source 0.3.4 alpha ».

État du code source consulté :
- \`compileSdk 36\`
- \`targetSdk 36\`
- \`minSdk 31\`
- Android Gradle Plugin déclaré : \`9.4.0\`
- Java source/target : \`17\`
- dépendances Shizuku \`api\` et \`provider\` : \`13.1.5\`
- \`versionName '0.3.4'\` sur le commit main audité
- aucun Gradle Wrapper dans l'arborescence
- workflow upstream existant limité au build Desktop macOS/Windows ; aucune compilation Android automatisée repérée.

## Politique Android 17 recommandée

Android 17 correspond à l'API 37. La documentation Android indique \`compileSdk = 37\` pour accéder aux nouvelles API et recommande de tester séparément les changements de comportement avant de passer \`targetSdk\` à 37. Elle précise aussi que le projet doit utiliser Android Gradle Plugin \`8.9.0-rc01\` ou supérieur pour cette chaîne SDK.

La voie prudente pour FlipEx est donc :
1. faire monter \`compileSdk\` à 37 sur une branche autorisée ;
2. conserver temporairement \`targetSdk\` à 36 ;
3. vérifier la compilation avec une version Gradle/AGP épinglée et un Gradle Wrapper ;
4. exécuter les tests de compatibilité API 37, notamment Binder/Shizuku, création/fermeture d'écran virtuel, service d'accessibilité et restauration ;
5. relever \`targetSdk\` seulement après validation des restrictions Android 17.

Le passage de \`targetSdk\` à 37 n'est pas un simple changement de numéro : il active les nouveaux comportements ciblant API 37. Il ne faut pas le faire avant les tests.

## Risque Shizuku — non résolu par simple mise à jour SDK

L'issue upstream Shizuku [#2681](https://github.com/RikkaApps/Shizuku/issues/2681), ouverte le 11 novembre 2026, décrit sur un appareil Samsung sous One UI 9 / Android 17 des problèmes d'affichage des applications autorisées et d'App Ops. L'issue [#2667](https://github.com/RikkaApps/Shizuku/issues/2667) rapporte une liste d'applications autorisées vide sur un Galaxy S24 FE après mise à jour One UI 9.

Ces signalements imposent un test sur le **Galaxy Z Flip6 réel**, mais ils ne prouvent pas à eux seuls que le Binder Shizuku ou le UserService particulier de FlipEx est cassé. Le diagnostic ADB ajouté ici détecte l'installation de l'application Shizuku ; il ne prétend pas vérifier \`Shizuku.pingBinder()\` ni la liaison du UserService.

## Nouvel outil ajouté à FlipdexOS

Fichier : \`scripts/diagnose-flipex-android.sh\`

Commande sur le Chromebook Lenovo Duet sous postmarketOS / Plasma :

\`\`\`bash
cd ~/FlipdexOS
git pull --ff-only origin main
bash scripts/diagnose-flipex-android.sh
\`\`\`

Pour enregistrer le rapport :

\`\`\`bash
bash scripts/diagnose-flipex-android.sh --output ~/flipex-android-report.txt
\`\`\`

Le script est strictement en lecture seule. Il ne démarre pas Shizuku, ne change aucun réglage, ne lance aucune commande de restauration et ne lit pas logcat. Il n'affiche pas le numéro de série ADB ni l'adresse IP du téléphone.

## Ce que le diagnostic vérifie

- fabricant, modèle, version Android, API SDK et propriété système One UI ;
- état des réglages de débogage USB et sans fil ;
- présence et version déclarée du paquet Shizuku ;
- présence et version déclarée du paquet FlipEx ;
- \`targetSdk\` de l'APK FlipEx installé ;
- présence éventuelle d'une entrée Shizuku dans la liste Binder, à titre indicatif uniquement.

Après le rapport, ouvrir Shizuku sur le téléphone et vérifier explicitement que le serveur affiche **« Shizuku is running »**. Ouvrir FlipEx et vérifier que sa carte de configuration indique que Shizuku est connecté. Un test d'écran HDMI reste nécessaire.

## Tests et limites

- \`tests/flipex-android-preflight.sh\` : scénarios ADB simulés (Galaxy Z Flip6 API 37 / One UI 9, paquets présents, paquets absents, appareil non autorisé).
- CI : syntaxe Bash, ShellCheck et test du diagnostic.
- Ces tests valident le script de diagnostic, pas l'APK FlipEx, le fonctionnement de Shizuku sur le téléphone ni le mode DeX matériel.

## Blocage restant avant de modifier l'application native

Pour modifier et redistribuer le code upstream FlipEx, il faut obtenir une licence ou une autorisation explicite du mainteneur. En outre, le compte connecté a uniquement un accès en lecture à ce dépôt externe. Aucun fichier upstream n'a été modifié.

Deux voies sûres pour la suite :
- obtenir l'autorisation du mainteneur, puis préparer une branche de correctifs et une CI Android ;
- à défaut, développer dans un dépôt sous contrôle de l'utilisateur une implémentation indépendante et propre, sans recopier le code non licencié.

## Sources techniques consultées

- [Configuration du SDK Android 17](https://developer.android.com/about/versions/17/setup-sdk)
- [Niveaux d'API Android](https://developer.android.com/guide/topics/manifest/uses-sdk-element)
- [Signalement Shizuku One UI 9 / Android 17 #2681](https://github.com/RikkaApps/Shizuku/issues/2681)
- [Signalement Shizuku Galaxy S24 FE / One UI 9 #2667](https://github.com/RikkaApps/Shizuku/issues/2667)
- [Code source FlipEx audité](https://github.com/Vedjamkar/flipex/tree/6bfdeb9f779bf921e659baf614a08021bcb529ec)
- [Dernière release FlipEx retournée par GitHub : v0.3.0](https://github.com/Vedjamkar/flipex/releases/tag/v0.3.0)

## Verdict

**Prévalidation FlipdexOS : implémentée.** Le Chromebook dispose maintenant d'un outil répétable pour établir l'état du Z Flip6 avant les essais de l'étape 3.

**Mise à jour de l'application native FlipEx : non livrée.** Elle reste bloquée par l'absence de licence déclarée et de droits d'écriture upstream. Aucun APK nouveau ni test matériel ne doit être annoncé comme réalisé.
