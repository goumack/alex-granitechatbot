# ALEX - Assistant IA avec RAG - Documentation de Déploiement

![Status](https://img.shields.io/badge/status-ready-green)
![OpenShift](https://img.shields.io/badge/platform-OpenShift-red)
![License](https://img.shields.io/badge/license-Proprietary-blue)

## Vue d'ensemble

ALEX est un assistant IA intelligent avec recherche augmentée par récupération (RAG) qui combine:

- **Ollama** pour les embeddings (nomic-embed-text)
- **NVIDIA NIM** pour le chat (Llama 3.2 3B Instruct)
- **ChromaDB** pour la base vectorielle
- **Flask** pour l'interface web
- **Surveillance automatique** des documents

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    ALEX Application                      │
├─────────────────────────────────────────────────────────┤
│                                                           │
│  ┌──────────────┐    ┌──────────────┐                   │
│  │   Ollama     │    │  NVIDIA NIM  │                   │
│  │  Embeddings  │    │     Chat     │                   │
│  │(nomic-embed) │    │(Llama 3.2 3B)│                   │
│  └──────┬───────┘    └──────┬───────┘                   │
│         │                   │                            │
│         └───────┬───────────┘                            │
│                 │                                        │
│         ┌───────▼────────┐                               │
│         │  Flask Backend │                               │
│         │   + ChromaDB   │                               │
│         └────────┬───────┘                               │
│                  │                                        │
│         ┌────────▼────────┐                              │
│         │   Documents +   │                              │
│         │  Auto-Indexing  │                              │
│         └─────────────────┘                              │
│                                                           │
└─────────────────────────────────────────────────────────┘
```

## Démarrage rapide

### Option 1: Déploiement automatique (Linux/Mac/Git Bash)

```bash
# 1. Se connecter à OpenShift
oc login --token=<VOTRE_TOKEN> --server=https://api.senum.heritage.africa:6443

# 2. Vérifier le fichier .env
cat .env  # Doit contenir NVIDIA_API_KEY

# 3. Lancer le déploiement
chmod +x deploy-alex.sh
./deploy-alex.sh deploy
```

### Option 2: Déploiement PowerShell (Windows)

```powershell
# 1. Se connecter à OpenShift
oc login --token=<VOTRE_TOKEN> --server=https://api.senum.heritage.africa:6443

# 2. Vérifier le fichier .env
Get-Content .env  # Doit contenir NVIDIA_API_KEY

# 3. Lancer le déploiement
.\deploy-alex.ps1 deploy
```

### Option 3: Déploiement manuel

Voir le [Guide de Déploiement Complet](GUIDE_DEPLOIEMENT.md)

## Documentation disponible

### 📚 Guides principaux

| Document | Description | Audience |
|----------|-------------|----------|
| [QUICKSTART.md](QUICKSTART.md) | Démarrage rapide en 5 étapes | Tous |
| [GUIDE_DEPLOIEMENT.md](GUIDE_DEPLOIEMENT.md) | Guide complet et détaillé | DevOps/Admin |
| [DEPLOIEMENT_WINDOWS.md](DEPLOIEMENT_WINDOWS.md) | Guide spécifique Windows | Utilisateurs Windows |
| [README_DEPLOIEMENT.md](README_DEPLOIEMENT.md) | Ce fichier - Vue d'ensemble | Tous |

### 🛠️ Scripts de déploiement

| Script | Description | Plateforme |
|--------|-------------|------------|
| [deploy-alex.sh](deploy-alex.sh) | Script bash automatique | Linux/Mac/Git Bash |
| deploy-alex.ps1 | Script PowerShell automatique | Windows PowerShell |

### ⚙️ Configuration OpenShift

| Fichier | Description |
|---------|-------------|
| [openshift/configmap.yaml](openshift/configmap.yaml) | Configuration hybride Ollama + NVIDIA |
| [openshift/deployment.yaml](openshift/deployment.yaml) | Définition du déploiement |
| [openshift/service-route.yaml](openshift/service-route.yaml) | Service et Route HTTPS |
| [openshift/storage.yaml](openshift/storage.yaml) | Volumes persistants (Documents + ChromaDB) |
| [openshift/secret.yaml.example](openshift/secret.yaml.example) | Exemple de secret NVIDIA |

## Configuration requise

### Prérequis système

- **OpenShift** 4.x ou supérieur
- **oc** CLI installé
- **podman** ou **docker** installé
- Accès à un cluster OpenShift avec:
  - Storage Class: `ocs-external-storagecluster-ceph-rbd`
  - Namespace: `alex-granitechatbot` (sera créé)

### Prérequis de configuration

1. **Clé API NVIDIA**
   - Obtenir depuis: https://build.nvidia.com/
   - Configurer dans le fichier `.env`

2. **Accès Ollama**
   - URL: `https://ollamaaccel-chatbotaccel.apps.senum.heritage.africa`
   - Modèle embeddings: `nomic-embed-text`

3. **Ressources minimales**
   - CPU: 250m (request), 1000m (limit)
   - Memory: 512Mi (request), 2Gi (limit)
   - Storage: 2Gi (documents) + 5Gi (ChromaDB)

## Structure du projet

```
ALEX/
├── taipy_version/
│   ├── app_taipy.py              # Application principale Flask
│   └── requirements.txt          # Dépendances Python
├── openshift/
│   ├── configmap.yaml            # Configuration application
│   ├── deployment.yaml           # Déploiement Kubernetes
│   ├── service-route.yaml        # Service et Route
│   ├── storage.yaml              # PersistentVolumeClaims
│   └── secret.yaml.example       # Exemple de secret
├── Dockerfile                    # Image Docker optimisée
├── .env                          # Variables d'environnement (ne pas commiter)
├── deploy-alex.sh                # Script de déploiement bash
├── QUICKSTART.md                 # Guide de démarrage rapide
├── GUIDE_DEPLOIEMENT.md          # Guide complet
├── DEPLOIEMENT_WINDOWS.md        # Guide Windows
└── README_DEPLOIEMENT.md         # Ce fichier
```

## Commandes essentielles

### Déploiement

```bash
# Déploiement complet
./deploy-alex.sh deploy

# Mise à jour de l'application
./deploy-alex.sh update

# Mise à jour de la configuration
./deploy-alex.sh config

# Redémarrer l'application
./deploy-alex.sh restart
```

### Monitoring

```bash
# Voir les logs
oc logs -f deployment/alex-deployment

# Status des pods
oc get pods -l app=alex

# Événements récents
oc get events --sort-by='.lastTimestamp' | grep alex

# Utilisation des ressources
oc adm top pods -l app=alex
```

### Gestion des documents

```bash
# Copier un document
oc cp mon-document.pdf deployment/alex-deployment:/app/documents/

# Lister les documents
oc exec deployment/alex-deployment -- ls -lh /app/documents/

# Vérifier l'indexation automatique
oc logs deployment/alex-deployment | grep "AUTO"
```

### Debugging

```bash
# Se connecter au pod
oc rsh deployment/alex-deployment

# Tester la connexion NVIDIA
oc exec deployment/alex-deployment -- curl -H "Authorization: Bearer $NVIDIA_API_KEY" https://integrate.api.nvidia.com/v1/models

# Tester la connexion Ollama
oc exec deployment/alex-deployment -- curl https://ollamaaccel-chatbotaccel.apps.senum.heritage.africa/api/version

# Vérifier ChromaDB
oc exec deployment/alex-deployment -- ls -la /app/chroma_db/
```

## Accès à l'application

Une fois déployée, l'application est accessible via:

```
https://alex-route-alex-granitechatbot.apps.senum.heritage.africa
```

### Endpoints disponibles

- `/` - Interface principale
- `/health` - Health check
- `/api/chat` - API de chat
- `/api/index` - API d'indexation

## Configuration

### Variables d'environnement (.env)

```bash
# Configuration Ollama (embeddings)
OLLAMA_BASE_URL=https://ollamaaccel-chatbotaccel.apps.senum.heritage.africa
OLLAMA_EMBEDDING_MODEL=nomic-embed-text

# Configuration NVIDIA NIM (chat)
NVIDIA_API_KEY=nvapi-VOTRE_CLE_API_ICI
NVIDIA_BASE_URL=https://integrate.api.nvidia.com/v1
NVIDIA_CHAT_MODEL=meta/llama-3.2-3b-instruct

# Configuration ChromaDB
CHROMA_PERSIST_DIRECTORY=./chroma_db

# Limites
MAX_FILE_SIZE_MB=10
CHUNK_SIZE=1000
CHUNK_OVERLAP=200
```

### ConfigMap OpenShift

Toutes les variables non sensibles sont dans [openshift/configmap.yaml](openshift/configmap.yaml).

### Secret OpenShift

La clé API NVIDIA est stockée dans un secret Kubernetes:

```bash
oc create secret generic alex-nvidia-secret \
  --from-literal=NVIDIA_API_KEY='votre-clé-api'
```

## Sécurité

### Bonnes pratiques appliquées

✅ **Utilisateur non-root** dans le conteneur (UID 1001)
✅ **Secrets Kubernetes** pour les informations sensibles
✅ **TLS/HTTPS** pour toutes les routes
✅ **Health checks** (liveness et readiness probes)
✅ **Resource limits** pour éviter la surconsommation
✅ **Volumes persistants** pour la données
✅ **Graceful shutdown** avec lifecycle hooks

### Points de vigilance

⚠️ **Ne jamais commiter** le fichier `.env` avec les vraies clés
⚠️ **Restreindre l'accès** aux secrets OpenShift
⚠️ **Sauvegarder régulièrement** les volumes persistants
⚠️ **Monitorer** l'utilisation des ressources
⚠️ **Mettre à jour** régulièrement les dépendances

## Maintenance

### Mise à jour de l'application

```bash
# 1. Modifier le code
# 2. Mettre à jour l'image
./deploy-alex.sh update

# 3. Vérifier le rollout
oc rollout status deployment/alex-deployment
```

### Sauvegarde

```bash
# Sauvegarder les documents
oc rsync deployment/alex-deployment:/app/documents ./backup/documents_$(date +%Y%m%d)

# Sauvegarder ChromaDB
oc rsync deployment/alex-deployment:/app/chroma_db ./backup/chroma_db_$(date +%Y%m%d)
```

### Restauration

```bash
# Restaurer les documents
oc rsync ./backup/documents_20250127/ deployment/alex-deployment:/app/documents/

# Restaurer ChromaDB
oc rsync ./backup/chroma_db_20250127/ deployment/alex-deployment:/app/chroma_db/

# Redémarrer
oc rollout restart deployment/alex-deployment
```

### Mise à l'échelle

```bash
# Augmenter le nombre de réplicas
oc scale deployment alex-deployment --replicas=3

# Vérifier
oc get pods -l app=alex
```

## Troubleshooting

### Problèmes courants

#### 1. Pod ne démarre pas

```bash
# Vérifier les événements
oc describe pod -l app=alex

# Vérifier les logs
oc logs deployment/alex-deployment

# Vérifier les ressources
oc get resourcequota
```

#### 2. Erreur de connexion NVIDIA

```bash
# Vérifier le secret
oc get secret alex-nvidia-secret -o yaml

# Tester l'API depuis le pod
oc exec deployment/alex-deployment -- curl -H "Authorization: Bearer $NVIDIA_API_KEY" https://integrate.api.nvidia.com/v1/models
```

#### 3. ChromaDB ne fonctionne pas

```bash
# Vérifier les permissions
oc exec deployment/alex-deployment -- ls -la /app/chroma_db/

# Réinitialiser la base (⚠️ perte de données)
oc exec deployment/alex-deployment -- rm -rf /app/chroma_db/*
oc rollout restart deployment/alex-deployment
```

#### 4. Documents non indexés

```bash
# Vérifier les logs de surveillance
oc logs deployment/alex-deployment | grep "AUTO"

# Vérifier les permissions du répertoire
oc exec deployment/alex-deployment -- ls -la /app/documents/
```

## Performance

### Optimisations appliquées

- ✅ Compilation de SQLite 3.45.0 pour ChromaDB
- ✅ Cache de réponses avec persistance
- ✅ Retry automatique pour les appels API
- ✅ Indexation asynchrone des documents
- ✅ Chunking optimisé (1000 caractères avec overlap de 200)
- ✅ Connection pooling pour les API externes

### Métriques

```bash
# Utilisation CPU/Memory
oc adm top pods -l app=alex

# Temps de réponse
oc logs deployment/alex-deployment | grep "Response time"

# Taux de succès des requêtes
oc logs deployment/alex-deployment | grep "success rate"
```

## Support et contact

### Documentation

- **Guide rapide**: [QUICKSTART.md](QUICKSTART.md)
- **Guide complet**: [GUIDE_DEPLOIEMENT.md](GUIDE_DEPLOIEMENT.md)
- **Guide Windows**: [DEPLOIEMENT_WINDOWS.md](DEPLOIEMENT_WINDOWS.md)

### Ressources externes

- **OpenShift**: https://docs.openshift.com/
- **Taipy**: https://docs.taipy.io/
- **ChromaDB**: https://docs.trychroma.com/
- **NVIDIA NIM**: https://build.nvidia.com/

### Contact

**Accel Tech**
📧 Email: contact@acceltech.africa
🌐 Website: https://acceltech.africa

## Licence

Copyright © 2025 Accel Tech. Tous droits réservés.

---

**Version**: 1.0
**Dernière mise à jour**: 2025-01-27
**Auteur**: Accel Tech
