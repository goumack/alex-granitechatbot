# Migration d'Ollama vers NVIDIA API

## Résumé des modifications

Ce document décrit la migration complète de l'application ALEX d'Ollama vers l'API NVIDIA.

### ✅ Tests réussis
Tous les tests ont été validés avec succès:
- ✅ Génération de chat
- ✅ Génération d'embeddings (1024 dimensions)
- ✅ Streaming de réponses

## Changements effectués

### 1. Configuration (.env)
**Ancien (Ollama):**
```
OLLAMA_BASE_URL=https://ollamaaccel-chatbotaccel.apps.senum.heritage.africa
OLLAMA_CHAT_MODEL=granite-code:3b
OLLAMA_EMBEDDING_MODEL=nomic-embed-text
```

**Nouveau (NVIDIA):**
```
NVIDIA_API_KEY=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
NVIDIA_BASE_URL=https://integrate.api.nvidia.com/v1
NVIDIA_CHAT_MODEL=meta/llama-3.2-3b-instruct
NVIDIA_EMBEDDING_MODEL=nvidia/nv-embedqa-e5-v5
```

### 2. Code Python

#### Import du SDK OpenAI
```python
from openai import OpenAI
```

#### Initialisation du client
```python
self.nvidia_client = OpenAI(
    base_url=self.config.NVIDIA_BASE_URL,
    api_key=self.config.NVIDIA_API_KEY
)
```

#### Génération d'embeddings
**Important:** NVIDIA nécessite le paramètre `input_type` pour les modèles asymétriques.

```python
response = self.nvidia_client.embeddings.create(
    input=[text],
    model=self.config.NVIDIA_EMBEDDING_MODEL,
    encoding_format="float",
    extra_body={"input_type": "query", "truncate": "NONE"}
)
```

#### Génération de chat
```python
completion = self.nvidia_client.chat.completions.create(
    model=self.config.NVIDIA_CHAT_MODEL,
    messages=[{"role": "user", "content": prompt}],
    temperature=0.2,
    top_p=0.7,
    max_tokens=1024,
    stream=False
)
```

#### Streaming
```python
completion = self.nvidia_client.chat.completions.create(
    model=self.config.NVIDIA_CHAT_MODEL,
    messages=[{"role": "user", "content": prompt}],
    temperature=0.2,
    top_p=0.7,
    max_tokens=1024,
    stream=True  # Activer le streaming
)

for chunk in completion:
    if chunk.choices[0].delta.content is not None:
        print(chunk.choices[0].delta.content, end="")
```

## Fichiers modifiés

1. **taipy_version/app_taipy copy 4.py** - Application principale
   - Configuration NVIDIA
   - Initialisation du client OpenAI
   - Fonction generate_embeddings()
   - Fonction chat()
   - Health check endpoint

2. **.env** - Variables d'environnement
   - Ajout des clés API NVIDIA
   - Remplacement des URLs Ollama

3. **test_nvidia_api.py** (nouveau) - Script de test
   - Tests de connexion
   - Tests de génération de chat
   - Tests d'embeddings
   - Tests de streaming

## Démarrage de l'application

```bash
# Vérifier que le package openai est installé
pip install openai

# Tester la connexion NVIDIA
python test_nvidia_api.py

# Démarrer l'application
python "taipy_version/app_taipy copy 4.py"
```

## Points importants

### Modèle d'embeddings NVIDIA
- Modèle: `nvidia/nv-embedqa-e5-v5`
- Dimensions: 1024
- **Obligatoire:** Le paramètre `input_type` doit être spécifié
- Valeurs possibles: `"query"` (pour les requêtes) ou `"passage"` (pour les documents)

### Modèle de chat NVIDIA
- Modèle: `meta/llama-3.2-3b-instruct`
- Température: 0.2 (réponses plus déterministes)
- Top P: 0.7
- Max tokens: 1024

## Avantages de la migration

1. **API Cloud:** Pas besoin d'héberger un serveur Ollama
2. **Performance:** Latence réduite avec les serveurs NVIDIA
3. **Fiabilité:** Infrastructure gérée par NVIDIA
4. **Scalabilité:** Gestion automatique de la charge
5. **Modèles optimisés:** Modèles NVIDIA spécialisés pour les embeddings

## Compatibilité

L'application reste 100% compatible avec l'interface existante. Seul le backend d'inférence a changé.

## Rollback

Pour revenir à Ollama, il suffit de:
1. Restaurer l'ancien fichier .env avec les configurations Ollama
2. Restaurer le code qui utilise `requests` au lieu d'OpenAI SDK
