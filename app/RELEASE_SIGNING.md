# Signature de publication Android

L'APK debug construite automatiquement par GitHub Actions utilise une clé debug éphémère. Elle sert aux essais et ne doit pas être considérée comme une version de publication.

La signature release doit rester contrôlée par le propriétaire du projet. **Ne place jamais le keystore, les mots de passe ou une clé privée dans Git.**

## 1. Générer une clé durable (une seule fois)

Depuis un ordinateur de confiance avec JDK 17 :

```bash
keytool -genkeypair -v \
  -keystore flipdexos-release.jks \
  -alias flipdexos \
  -keyalg RSA -keysize 4096 \
  -validity 10000
```

Conserve le fichier JKS dans deux sauvegardes chiffrées séparées. Perdre cette clé empêchera les mises à jour signées avec la même identité de remplacer l'application installée.

## 2. Ajouter les secrets dans GitHub

Dans le dépôt, ouvre **Settings → Secrets and variables → Actions → New repository secret** et crée :

- `FLIPDEX_KEYSTORE_BASE64` : contenu base64 du fichier JKS ;
- `FLIPDEX_KEYSTORE_PASSWORD` : mot de passe du keystore ;
- `FLIPDEX_KEY_ALIAS` : `flipdexos` (ou l'alias choisi) ;
- `FLIPDEX_KEY_PASSWORD` : mot de passe de la clé.

Pour produire la valeur base64 sans modifier le JKS :

Linux :
```bash
base64 -w 0 flipdexos-release.jks
```

macOS :
```bash
base64 < flipdexos-release.jks | tr -d '\n'
```

Ne colle jamais les mots de passe dans un terminal partagé ou une conversation publique.

## 3. Produire l'APK release signée

Dans GitHub → Actions → **Signer l'APK de publication FlipdexOS** → Run workflow.

Le workflow s'arrête immédiatement si un secret manque. Il compile la variante release, contrôle l'alignement avec zipalign, vérifie la signature avec apksigner, calcule SHA-256 et publie un artefact de 90 jours.

La compilation locale utilise les mêmes variables d'environnement :

- `FLIPDEX_KEYSTORE_PATH`
- `FLIPDEX_KEYSTORE_PASSWORD`
- `FLIPDEX_KEY_ALIAS`
- `FLIPDEX_KEY_PASSWORD`

Puis :
```bash
gradle --no-daemon :app:assembleRelease
```

## 4. Transition depuis l'APK debug

Une APK release signée avec cette nouvelle clé ne peut pas mettre à jour une installation signée par la clé debug GitHub. Pour le premier passage, il faudra désinstaller la version debug puis installer la release ; la désinstallation efface les données privées de l'application.

Une fois la release installée, toutes les mises à jour futures doivent conserver exactement le même keystore, alias et certificat.
