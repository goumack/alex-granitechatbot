# Guide de Déploiement ALEX sur OpenShift

## Vue d'ensemble

ALEX est une application d'assistant IA avec RAG (Retrieval-Augmented Generation) qui utilise:
- **Ollama** pour les embeddings (modèle nomic-embed-text)
- **NVIDIA NIM** pour le chat (modèle Llama 3.2 3B Instruct)
- **ChromaDB** pour la base vectorielle
- **Flask** pour l'interface web
- **Surveillance automatique** des documents

## Prérequis

### 1. Accès OpenShift
```bash
# Se connecter à OpenShift
oc login --token=<VOTRE_TOKEN> --server=https://api.senum.heritage.africa:6443

# Vérifier la connexion
oc whoami
oc project
```

### 2. Variables d'environnement requises
- `NVIDIA_API_KEY`: Clé API NVIDIA (obligatoire)
- `OLLAMA_BASE_URL`: URL du serveur Ollama
- `NVIDIA_BASE_URL`: URL de l'API NVIDIA NIM
- `NVIDIA_CHAT_MODEL`: Modèle de chat NVIDIA

### 3. Outils nécessaires
- `oc` CLI (OpenShift CLI)
- `podman` ou `docker`
- Accès au registry OpenShift

## Architecture du déploiement

```
┌─────────────────────────────────────────────────────────┐
│                    OpenShift Cluster                     │
│                                                           │
│  ┌────────────────────────────────────────────────────┐  │
│  │              alex-granitechatbot (Namespace)        │  │
│  │                                                      │  │
│  │  ┌─────────────┐      ┌──────────────┐             │  │
│  │  │   Route     │──────▶│   Service    │             │  │
│  │  │  (HTTPS)    │      │  (ClusterIP)  │             │  │
│  │  └─────────────┘      └───────┬──────┘             │  │
│  │                               │                      │  │
│  │                       ┌───────▼────────┐             │  │
│  │                       │   Deployment   │             │  │
│  │                       │  (alex-pod)    │             │  │
│  │                       │                │             │  │
│  │                       │  ┌──────────┐  │             │  │
│  │                       │  │  Flask   │  │             │  │
│  │                       │  │   App    │  │             │  │
│  │                       │  └─────┬────┘  │             │  │
│  │                       │        │       │             │  │
│  │   ┌────────┐          │  ┌─────▼────┐ │             │  │
│  │   │ConfigMap│─────────▶│ ChromaDB  │ │             │  │
│  │   └────────┘          │  └──────────┘ │             │  │
│  │                       │        │       │             │  │
│  │   ┌────────┐          │  ┌─────▼────┐ │             │  │
│  │   │ Secret │─────────▶│ Documents │ │             │  │
│  │   └────────┘          │  └──────────┘ │             │  │
│  │                       └────────────────┘             │  │
│  │                               │                      │  │
│  │                       ┌───────▼────────┐             │  │
│  │                       │ Persistent     │             │  │
│  │                       │ Volumes (PVC)  │             │  │
│  │                       │  - Documents   │             │  │
│  │                       │  - ChromaDB    │             │  │
│  │                       └────────────────┘             │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                             │
│  Connexions externes:                                       │
│  - Ollama: https://ollamaaccel-chatbotaccel.apps...       │
│  - NVIDIA NIM: https://integrate.api.nvidia.com/v1         │
└─────────────────────────────────────────────────────────────┘
```

## Étapes de déploiement

### Étape 1: Créer ou vérifier le namespace

```bash
# Créer le namespace (si pas déjà créé)
oc new-project alex-granitechatbot

# Ou utiliser un namespace existant
oc project alex-granitechatbot
```

### Étape 2: Créer le Secret pour NVIDIA API Key

⚠️ **IMPORTANT**: Ne jamais commiter la clé API dans le code source!

```bash
# Créer le secret avec votre clé NVIDIA
oc create secret generic alex-nvidia-secret \
  --from-literal=NVIDIA_API_KEY='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'

# Vérifier le secret
oc get secret alex-nvidia-secret
```

### Étape 3: Créer les ressources de stockage

```bash
# Créer les PersistentVolumeClaims
oc apply -f openshift/storage.yaml

# Vérifier les PVCs
oc get pvc
```

Sortie attendue:
```
NAME                  STATUS   VOLUME       CAPACITY   ACCESS MODES   STORAGECLASS
alex-documents-pvc    Bound    pvc-xxx...   2Gi        RWO            ocs-external-storagecluster-ceph-rbd
alex-chroma-pvc       Bound    pvc-yyy...   5Gi        RWO            ocs-external-storagecluster-ceph-rbd
```

### Étape 4: Créer la ConfigMap

```bash
# Créer la ConfigMap avec la configuration hybride
oc apply -f openshift/configmap.yaml

# Vérifier la ConfigMap
oc describe configmap alex-config
```

### Étape 5: Construire et pousser l'image Docker

```bash
# Se connecter au registry OpenShift
podman login -u $(oc whoami) -p $(oc whoami -t) image-registry.openshift-image-registry.svc:5000

# Construire l'image
podman build -t alex-optimized:latest -f Dockerfile .

# Tagger l'image pour le registry OpenShift
podman tag alex-optimized:latest image-registry.openshift-image-registry.svc:5000/alex-granitechatbot/alex-optimized:latest

# Pousser l'image vers le registry
podman push image-registry.openshift-image-registry.svc:5000/alex-granitechatbot/alex-optimized:latest
```

### Étape 6: Déployer l'application

```bash
# Créer le déploiement
oc apply -f openshift/deployment.yaml

# Vérifier le déploiement
oc get deployment alex-deployment

# Vérifier les pods
oc get pods -l app=alex
```

### Étape 7: Créer le Service et la Route

```bash
# Créer le service et la route
oc apply -f openshift/service-route.yaml

# Vérifier le service
oc get service alex-service

# Vérifier la route et obtenir l'URL
oc get route alex-route
```

### Étape 8: Vérifier le déploiement

```bash
# Voir les logs du pod
oc logs -f deployment/alex-deployment

# Vérifier l'état du pod
oc describe pod -l app=alex

# Tester le endpoint health
oc exec deployment/alex-deployment -- curl http://localhost:8505/health
```

## Accès à l'application

Une fois déployé, l'application est accessible via la route:

```bash
# Obtenir l'URL de l'application
oc get route alex-route -o jsonpath='{.spec.host}'
```

L'URL sera du type: `https://alex-route-alex-granitechatbot.apps.senum.heritage.africa`

## Configuration avancée

### Mise à jour de la configuration

Pour modifier la configuration sans redéployer:

```bash
# Éditer la ConfigMap
oc edit configmap alex-config

# Redémarrer les pods pour appliquer les changements
oc rollout restart deployment alex-deployment
```

### Mise à jour de l'application

```bash
# Reconstruire et pousser la nouvelle image
podman build -t alex-optimized:latest -f Dockerfile .
podman tag alex-optimized:latest image-registry.openshift-image-registry.svc:5000/alex-granitechatbot/alex-optimized:latest
podman push image-registry.openshift-image-registry.svc:5000/alex-granitechatbot/alex-optimized:latest

# Forcer le redéploiement
oc rollout restart deployment alex-deployment

# Suivre le rollout
oc rollout status deployment alex-deployment
```

### Scaling

```bash
# Augmenter le nombre de réplicas
oc scale deployment alex-deployment --replicas=3

# Vérifier
oc get pods -l app=alex
```

### Ajustement des ressources

Modifier les limites de ressources dans [deployment.yaml](openshift/deployment.yaml):

```yaml
resources:
  requests:
    memory: "1Gi"      # Minimum requis
    cpu: "500m"
  limits:
    memory: "4Gi"      # Maximum autorisé
    cpu: "2000m"
```

Puis appliquer:
```bash
oc apply -f openshift/deployment.yaml
```

## Surveillance et maintenance

### Logs

```bash
# Voir les logs en temps réel
oc logs -f deployment/alex-deployment

# Voir les logs des 100 dernières lignes
oc logs deployment/alex-deployment --tail=100

# Logs de tous les pods
oc logs -l app=alex --all-containers=true
```

### Métriques

```bash
# Utilisation des ressources
oc adm top pods -l app=alex

# Événements récents
oc get events --sort-by='.lastTimestamp' | grep alex
```

### Health checks

```bash
# Vérifier la santé de l'application
curl -k https://$(oc get route alex-route -o jsonpath='{.spec.host}')/health

# Ou depuis un pod
oc exec deployment/alex-deployment -- curl http://localhost:8505/health
```

### Debugging

```bash
# Se connecter au pod pour debugging
oc rsh deployment/alex-deployment

# Exécuter des commandes dans le pod
oc exec deployment/alex-deployment -- ls -la /app/documents
oc exec deployment/alex-deployment -- ls -la /app/chroma_db

# Vérifier les variables d'environnement
oc exec deployment/alex-deployment -- env | grep -E "(OLLAMA|NVIDIA)"
```

## Gestion des documents

### Ajouter des documents

```bash
# Copier un document vers le pod
oc cp mon-document.pdf deployment/alex-deployment:/app/documents/

# Vérifier que le document a été indexé (voir les logs)
oc logs deployment/alex-deployment | grep "AUTO"
```

### Lister les documents indexés

```bash
# Se connecter au pod et vérifier
oc exec deployment/alex-deployment -- ls -lh /app/documents/
```

## Troubleshooting

### Le pod ne démarre pas

```bash
# Vérifier les événements
oc describe pod -l app=alex

# Vérifier les limites de ressources
oc get resourcequota

# Vérifier les PVCs
oc get pvc
```

### Erreur de permission

```bash
# Vérifier les permissions du pod
oc exec deployment/alex-deployment -- id

# Vérifier les permissions des volumes
oc exec deployment/alex-deployment -- ls -la /app
```

### Erreur de connexion à Ollama ou NVIDIA

```bash
# Tester la connexion depuis le pod
oc exec deployment/alex-deployment -- curl -v https://ollamaaccel-chatbotaccel.apps.senum.heritage.africa/api/version

# Tester NVIDIA API
oc exec deployment/alex-deployment -- curl -H "Authorization: Bearer $NVIDIA_API_KEY" https://integrate.api.nvidia.com/v1/models
```

### Problème de base de données ChromaDB

```bash
# Vérifier la base ChromaDB
oc exec deployment/alex-deployment -- ls -la /app/chroma_db/

# Supprimer et recréer la base (⚠️ perte de données)
oc exec deployment/alex-deployment -- rm -rf /app/chroma_db/*
oc rollout restart deployment alex-deployment
```

## Sauvegarde et restauration

### Sauvegarde

```bash
# Créer un snapshot des PVCs (si supporté par le storage class)
oc create -f - <<EOF
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: alex-chroma-snapshot-$(date +%Y%m%d)
spec:
  volumeSnapshotClassName: ocs-external-storagecluster-ceph-rbd
  source:
    persistentVolumeClaimName: alex-chroma-pvc
EOF

# Ou copier les données localement
oc rsync deployment/alex-deployment:/app/chroma_db ./backup/chroma_db_$(date +%Y%m%d)
oc rsync deployment/alex-deployment:/app/documents ./backup/documents_$(date +%Y%m%d)
```

### Restauration

```bash
# Restaurer depuis une copie locale
oc rsync ./backup/chroma_db_20250127/ deployment/alex-deployment:/app/chroma_db/
oc rsync ./backup/documents_20250127/ deployment/alex-deployment:/app/documents/

# Redémarrer le pod
oc rollout restart deployment alex-deployment
```

## Suppression complète

Pour supprimer complètement l'application:

```bash
# Supprimer toutes les ressources
oc delete -f openshift/service-route.yaml
oc delete -f openshift/deployment.yaml
oc delete -f openshift/configmap.yaml
oc delete -f openshift/storage.yaml
oc delete secret alex-nvidia-secret

# Ou supprimer tout le namespace
oc delete project alex-granitechatbot
```

## Sécurité

### Bonnes pratiques

1. **Ne jamais commiter de secrets** dans Git
2. **Utiliser des secrets OpenShift** pour les clés API
3. **Activer TLS** pour toutes les routes (déjà configuré)
4. **Limiter les ressources** pour éviter la surconsommation
5. **Utiliser des comptes non-root** (déjà configuré dans le Dockerfile)
6. **Sauvegarder régulièrement** les données

### Rotation des secrets

```bash
# Mettre à jour le secret NVIDIA
oc delete secret alex-nvidia-secret
oc create secret generic alex-nvidia-secret \
  --from-literal=NVIDIA_API_KEY='NOUVELLE_CLE'

# Redémarrer pour appliquer
oc rollout restart deployment alex-deployment
```

## Support et documentation

- **Documentation Taipy**: https://docs.taipy.io/
- **Documentation ChromaDB**: https://docs.trychroma.com/
- **Documentation OpenShift**: https://docs.openshift.com/
- **NVIDIA NIM API**: https://build.nvidia.com/

## Auteur

**Accel Tech**
- Contact: contact@acceltech.africa
- Version: 1.0
