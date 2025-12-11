# Guide de Démarrage Rapide - Déploiement ALEX sur OpenShift

## Prérequis rapides

1. **Outils installés:**
   - `oc` (OpenShift CLI)
   - `podman` ou `docker`

2. **Accès OpenShift configuré:**
   ```bash
   oc login --token=<VOTRE_TOKEN> --server=https://api.senum.heritage.africa:6443
   ```

3. **Clé API NVIDIA:**
   - Obtenez votre clé API depuis: https://build.nvidia.com/

## Déploiement en 5 étapes

### Étape 1: Vérifier le fichier .env

Assurez-vous que le fichier [.env](.env) contient votre clé API NVIDIA:

```bash
cat .env
```

Devrait contenir:
```
NVIDIA_API_KEY=nvapi-VOTRE_CLE_API
NVIDIA_BASE_URL=https://integrate.api.nvidia.com/v1
NVIDIA_CHAT_MODEL=meta/llama-3.2-3b-instruct
OLLAMA_BASE_URL=https://ollamaaccel-chatbotaccel.apps.senum.heritage.africa
OLLAMA_EMBEDDING_MODEL=nomic-embed-text
```

### Étape 2: Rendre le script exécutable

```bash
chmod +x deploy-alex.sh
```

### Étape 3: Lancer le déploiement complet

```bash
./deploy-alex.sh deploy
```

OU utilisez le menu interactif:

```bash
./deploy-alex.sh
```

Puis choisissez l'option 1 (Déploiement complet).

### Étape 4: Attendre la fin du déploiement

Le script va automatiquement:
- ✅ Créer le namespace `alex-granitechatbot`
- ✅ Créer le secret NVIDIA
- ✅ Créer les volumes persistants
- ✅ Créer la ConfigMap
- ✅ Construire et pousser l'image Docker
- ✅ Déployer l'application
- ✅ Créer le Service et la Route

### Étape 5: Accéder à l'application

À la fin du déploiement, l'URL de l'application sera affichée:

```
URL de l'application: https://alex-route-alex-granitechatbot.apps.senum.heritage.africa
```

## Vérification rapide

### Vérifier les pods
```bash
oc get pods -l app=alex
```

### Voir les logs
```bash
oc logs -f deployment/alex-deployment
```

### Tester l'endpoint health
```bash
curl -k https://alex-route-alex-granitechatbot.apps.senum.heritage.africa/health
```

## Commandes utiles

### Mettre à jour l'application après des modifications de code
```bash
./deploy-alex.sh update
```

### Mettre à jour la configuration
```bash
./deploy-alex.sh config
```

### Redémarrer l'application
```bash
./deploy-alex.sh restart
```

### Afficher les informations de déploiement
```bash
./deploy-alex.sh info
```

### Voir les logs en temps réel
```bash
./deploy-alex.sh logs
```

## Ajouter des documents

### Copier un document vers l'application
```bash
oc cp mon-document.pdf deployment/alex-deployment:/app/documents/
```

Le document sera automatiquement indexé dans ChromaDB.

## Troubleshooting rapide

### Le pod ne démarre pas
```bash
# Voir les événements
oc describe pod -l app=alex

# Voir les logs
oc logs deployment/alex-deployment
```

### Erreur de connexion NVIDIA
```bash
# Vérifier que la clé API est bien configurée
oc exec deployment/alex-deployment -- env | grep NVIDIA_API_KEY

# Tester la connexion depuis le pod
oc exec deployment/alex-deployment -- curl -H "Authorization: Bearer $NVIDIA_API_KEY" https://integrate.api.nvidia.com/v1/models
```

### Réinitialiser l'application
```bash
# Supprimer complètement l'application
./deploy-alex.sh delete

# Redéployer
./deploy-alex.sh deploy
```

## Architecture simplifiée

```
Internet
   ↓
[Route HTTPS]
   ↓
[Service ClusterIP]
   ↓
[Pod ALEX]
   ├─ Flask App
   ├─ ChromaDB
   └─ Documents
   ↓
[Connexions externes]
   ├─ Ollama (embeddings)
   └─ NVIDIA NIM (chat)
```

## Support

Pour plus de détails, consultez le [Guide de Déploiement Complet](GUIDE_DEPLOIEMENT.md).

## Résumé des fichiers

- **deploy-alex.sh**: Script de déploiement automatique
- **GUIDE_DEPLOIEMENT.md**: Guide complet avec tous les détails
- **QUICKSTART.md**: Ce guide de démarrage rapide
- **openshift/**: Tous les fichiers de configuration Kubernetes
  - configmap.yaml: Configuration de l'application
  - deployment.yaml: Définition du déploiement
  - service-route.yaml: Service et Route
  - storage.yaml: Volumes persistants
  - secret.yaml.example: Exemple de secret (ne pas commiter la vraie clé)

## Checklist de déploiement

- [ ] Installer `oc` CLI
- [ ] Installer `podman`
- [ ] Se connecter à OpenShift (`oc login`)
- [ ] Configurer le fichier `.env` avec la clé NVIDIA
- [ ] Rendre le script exécutable (`chmod +x deploy-alex.sh`)
- [ ] Lancer le déploiement (`./deploy-alex.sh deploy`)
- [ ] Vérifier les pods (`oc get pods -l app=alex`)
- [ ] Accéder à l'URL de l'application
- [ ] Tester l'endpoint health
- [ ] Ajouter des documents de test

Bonne chance avec votre déploiement ! 🚀
