# 🚀 Procédure de Déploiement ALEX - Fix SSL Ollama

## ✅ Changements Appliqués

### 1. Fix SSL pour Ollama (certificat expiré)
- **Fichier**: `openshift/deployment.yaml`
  - Ajout variables d'environnement pour désactiver SSL:
    - `PYTHONHTTPSVERIFY=0`
    - `REQUESTS_CA_BUNDLE=""`
    - `CURL_CA_BUNDLE=""`
    - `SSL_CERT_FILE=""`
  - Fix nom du secret: `nvidia-secret` → `alex-nvidia-secret`

### 2. Script Entrypoint
- **Fichier**: `taipy_version/entrypoint.sh`
  - Fix SQLite pour ChromaDB (pysqlite3)
  - Configuration SSL désactivée

### 3. Code Principal
- **Fichier**: `taipy_version/app_taipy.py`
  - Copie de `app_taipy_nim_nvidia_8bmistral.py`
  - verify=False dans requests

## 🔄 Étapes de Déploiement

### Étape 1 : Commit et Push vers GitHub

```bash
cd "/c/Users/baye.niang/Desktop/Projets et realisations/ALEX"

# Ajouter les fichiers modifiés
git add openshift/deployment.yaml
git add taipy_version/app_taipy.py
git add taipy_version/entrypoint.sh
git add taipy_version/requirements.txt
git add Dockerfile

# Créer le commit
git commit -m "fix: Désactiver vérification SSL pour Ollama (certificat expiré)

- Ajout variables d'environnement SSL dans deployment.yaml
- Fix nom du secret NVIDIA
- Script entrypoint.sh pour fix SQLite + SSL
- Copie app_taipy_nim_nvidia_8bmistral.py vers app_taipy.py

Résout l'erreur: SSLError(SSLCertVerificationError certificate has expired)"

# Push vers GitHub
git push origin master
```

### Étape 2 : Déclencher le Build OpenShift

**Depuis votre terminal OCP (où vous êtes connecté) :**

```bash
# Se positionner dans le bon namespace
oc project alex-granitechatbot

# Déclencher un nouveau build depuis GitHub
oc start-build alex-deployment-build --follow

# OU si vous voulez attendre que le webhook GitHub déclenche automatiquement
# (cela peut prendre quelques minutes après le push)
```

### Étape 3 : Mettre à jour le Deployment

```bash
# Appliquer le deployment.yaml mis à jour
oc apply -f openshift/deployment.yaml

# Forcer le redémarrage pour prendre en compte les nouvelles variables
oc rollout restart deployment/alex-deployment

# Surveiller le déploiement
oc rollout status deployment/alex-deployment
```

### Étape 4 : Vérification

```bash
# Voir les logs du nouveau pod
oc logs -f deployment/alex-deployment

# Vérifier le statut de santé
curl https://alex-route-alex-granitechatbot.apps.ocp.heritage.africa/health

# Devrait afficher:
# {
#   "nvidia_status": "🟢 Connecté",
#   "ollama_status": "🟢 Connecté",  <-- DOIT PASSER À CONNECTÉ
#   ...
# }
```

## 🎯 Résultat Attendu

Après le déploiement, l'erreur SSL devrait disparaître et Ollama devrait être **🟢 Connecté**.

Les logs devraient montrer :
```
✅ Embedding généré avec succès (tentative 1)
✅ Contexte trouvé: 5 documents
```

Au lieu de :
```
❌ Erreur embedding: SSLError certificate verify failed
💥 Échec génération embedding après 3 tentatives
```

## ⚠️ Troubleshooting

### Si Ollama reste déconnecté :

1. Vérifier que les variables d'environnement sont bien chargées :
```bash
oc exec deployment/alex-deployment -- env | grep -E "PYTHON|SSL|CA_BUNDLE"
```

2. Vérifier les logs détaillés :
```bash
oc logs deployment/alex-deployment --tail=200
```

3. Tester manuellement depuis le pod :
```bash
oc exec deployment/alex-deployment -- python3 -c "
import requests
import urllib3
urllib3.disable_warnings()
r = requests.get('https://ollamaaccel-chatbotaccel.apps.senum.heritage.africa/api/tags', verify=False)
print(r.status_code)
"
```

