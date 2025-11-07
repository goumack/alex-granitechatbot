# Guide de déploiement ALEX sur OpenShift

## Prérequis

- Accès à un cluster OpenShift avec permissions de déploiement
- CLI `oc` installé et connecté au cluster
- Docker/Podman pour construire l'image (optionnel si registry externe)

## Étapes de déploiement

### 1. Préparation du projet OpenShift

```bash
# Créer un nouveau projet
oc new-project alex-prod --display-name="ALEX Assistant IA" --description="Assistant IA RAG d'Accel Tech"

# Se positionner dans le projet
oc project alex-prod
```

### 2. Construction et push de l'image Docker

#### Option A: Build local + push vers registry OpenShift interne

```bash
# Se connecter au registry interne OpenShift
oc whoami -t | docker login -u $(oc whoami) --password-stdin $(oc get route default-route -n openshift-image-registry --template='{{ .spec.host }}')

# Build et tag l'image
docker build -t alex:latest .

# Tag pour le registry OpenShift
docker tag alex:latest $(oc get route default-route -n openshift-image-registry --template='{{ .spec.host }}')/alex-prod/alex:latest

# Push vers le registry
docker push $(oc get route default-route -n openshift-image-registry --template='{{ .spec.host }}')/alex-prod/alex:latest
```

#### Option B: Build direct avec OpenShift (BuildConfig)

```bash
# Créer un BuildConfig depuis le Dockerfile local
oc new-build --dockerfile="$(cat Dockerfile)" --name=alex

# Démarrer le build
oc start-build alex --from-dir=./taipy_version --follow

# Attendre la fin du build
oc logs -f bc/alex
```

### 3. Déploiement des ressources Kubernetes

```bash
# Appliquer les manifestes dans l'ordre
oc apply -f openshift/configmap.yaml
oc apply -f openshift/storage.yaml
oc apply -f openshift/deployment.yaml
oc apply -f openshift/service-route.yaml
```

### 4. Vérification du déploiement

```bash
# Vérifier les ressources créées
oc get all -l app=alex

# Vérifier les pods
oc get pods -w

# Consulter les logs
oc logs -f deployment/alex-deployment

# Vérifier la route
oc get route alex-route
```

### 5. Configuration post-déploiement

#### Uploader des documents (optionnel)

```bash
# Copier des documents dans le pod
oc cp ./documents/. $(oc get pods -l app=alex -o jsonpath='{.items[0].metadata.name}'):/app/documents/

# Déclencher la réindexation
curl -X POST https://$(oc get route alex-route -o jsonpath='{.spec.host}')/force_full_reindex
```

## URLs d'accès

Une fois déployé, ALEX sera accessible via :

```bash
# Obtenir l'URL publique
echo "https://$(oc get route alex-route -o jsonpath='{.spec.host}')/"
```

Endpoints disponibles :
- `GET /` - Interface utilisateur
- `POST /chat` - API de chat
- `GET /health` - Vérification de santé
- `GET /status` - Statut de l'indexation
- `POST /force_full_reindex` - Réindexation complète

## Monitoring et maintenance

### Consulter les logs

```bash
# Logs en temps réel
oc logs -f deployment/alex-deployment

# Logs des dernières 24h
oc logs deployment/alex-deployment --since=24h
```

### Mise à l'échelle

```bash
# Augmenter le nombre de réplicas
oc scale deployment alex-deployment --replicas=2

# Vérifier l'état
oc get pods -l app=alex
```

### Mise à jour de l'application

```bash
# Rebuild l'image
oc start-build alex --follow

# Redéployer automatiquement (si ImageChangeTrigger configuré)
# Ou forcer un nouveau déploiement
oc rollout restart deployment/alex-deployment

# Suivre le rollout
oc rollout status deployment/alex-deployment
```

### Sauvegarde des données

```bash
# Sauvegarder les documents
oc cp $(oc get pods -l app=alex -o jsonpath='{.items[0].metadata.name}'):/app/documents ./backup-documents/

# Sauvegarder la base ChromaDB
oc cp $(oc get pods -l app=alex -o jsonpath='{.items[0].metadata.name}'):/app/chroma_db ./backup-chroma/
```

## Dépannage

### Problèmes courants

1. **Pod en CrashLoopBackOff**
   ```bash
   oc describe pod <pod-name>
   oc logs <pod-name> --previous
   ```

2. **Problème de connexion à Ollama**
   - Vérifier la ConfigMap : `oc describe configmap alex-config`
   - Tester la connectivité : `oc exec deployment/alex-deployment -- curl -I https://ollamaaccel-chatbotaccel.apps.senum.heritage.africa/api/tags`

3. **Problèmes de stockage**
   ```bash
   oc describe pvc alex-documents-pvc
   oc describe pvc alex-chroma-pvc
   ```

4. **Problèmes de route/réseau**
   ```bash
   oc describe route alex-route
   oc get endpoints alex-service
   ```

### Variables d'environnement importantes

Modifiables via la ConfigMap (`oc edit configmap alex-config`) :

- `OLLAMA_BASE_URL` - URL du service Ollama
- `OLLAMA_CHAT_MODEL` - Modèle de chat (granite-code:3b)
- `OLLAMA_EMBEDDING_MODEL` - Modèle d'embeddings (nomic-embed-text)
- `ALEX_RESPONSE_CACHE_MAX` - Taille du cache de réponses
- `ALEX_PERSIST_CACHE` - Activation du cache persistant
- `LOG_LEVEL` - Niveau de logs (DEBUG, INFO, WARNING, ERROR)

Après modification de la ConfigMap :
```bash
oc rollout restart deployment/alex-deployment
```

## Sécurité

- L'application tourne avec un utilisateur non-root (UID 1001)
- TLS activé automatiquement via la Route OpenShift
- Ressources limitées pour éviter la consommation excessive
- Health checks configurés pour la haute disponibilité

## Performance

### Recommandations de ressources

- **Développement** : 512Mi RAM, 250m CPU
- **Production** : 2Gi RAM, 1000m CPU
- **Stockage** : 2Gi documents + 5Gi ChromaDB

### Optimisations

1. Activer le cache persistant (`ALEX_PERSIST_CACHE=true`)
2. Ajuster la taille du cache (`ALEX_RESPONSE_CACHE_MAX`)
3. Monitorer l'utilisation mémoire des embeddings
4. Utiliser des node selectors pour les gros workloads

## Support

Pour toute question ou problème :
- Consulter les logs : `oc logs deployment/alex-deployment`
- Vérifier la santé : `curl https://<route-host>/health`
- Contacter l'équipe Accel Tech