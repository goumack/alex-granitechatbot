# Configuration Hybride: Ollama + NVIDIA NIM

## Architecture

ALEX utilise maintenant une **configuration hybride** optimale:

```
┌─────────────────────────────────────────┐
│         ALEX Application                │
├─────────────────────────────────────────┤
│                                         │
│  Embeddings ──► Ollama                 │
│  (nomic-embed-text)                    │
│  └─ URL: ollamaaccel.senum.africa     │
│                                         │
│  Chat ──► NVIDIA NIM                   │
│  (meta/llama-3.2-3b-instruct)          │
│  └─ URL: integrate.api.nvidia.com     │
│                                         │
└─────────────────────────────────────────┘
```

## Pourquoi cette configuration?

### Embeddings avec Ollama
✅ **Nomic-embed-text** est optimisé pour votre cas d'usage
✅ Infrastructure Ollama déjà en place et testée
✅ Pas de coût d'API pour les embeddings
✅ Faible latence avec serveur local

### Chat avec NVIDIA NIM
✅ **Meta Llama 3.2** offre une meilleure qualité de réponse
✅ Infrastructure cloud scalable
✅ Pas besoin de maintenir un serveur Ollama pour le chat
✅ API REST moderne avec SDK OpenAI

## Configuration (.env)

```bash
# Ollama pour embeddings
OLLAMA_BASE_URL=https://ollamaaccel-chatbotaccel.apps.senum.heritage.africa
OLLAMA_EMBEDDING_MODEL=nomic-embed-text

# NVIDIA NIM pour chat
NVIDIA_API_KEY=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
NVIDIA_BASE_URL=https://integrate.api.nvidia.com/v1
NVIDIA_CHAT_MODEL=meta/llama-3.2-3b-instruct

# ChromaDB
CHROMA_PERSIST_DIRECTORY=./chroma_db

# Application
APP_TITLE=ALEX - Assistant IA avec RAG
APP_DESCRIPTION=Chatbot intelligent avec recherche dans la base de connaissances
```

## Flux de données

### 1. Indexation de documents
```
Document ──► Chunking ──► Ollama (embeddings) ──► ChromaDB
```

### 2. Requête utilisateur
```
Question ──► Ollama (embedding) ──► ChromaDB (search) ──► Context
                                                            │
                                                            ▼
User ◄── NVIDIA NIM (génération) ◄─────────────── Context + Question
```

## Code Principal

### Génération d'embeddings (Ollama)
```python
def generate_embeddings(self, text: str) -> List[float]:
    """Génère des embeddings avec Ollama (nomic-embed-text)"""
    payload = {
        "model": self.config.OLLAMA_EMBEDDING_MODEL,
        "prompt": text
    }

    response = self._session.post(
        f"{self.config.OLLAMA_BASE_URL}/api/embeddings",
        json=payload,
        timeout=30
    )

    return response.json()['embedding']
```

### Génération de chat (NVIDIA NIM)
```python
def chat(self, message: str) -> str:
    """Génère une réponse avec NVIDIA NIM"""
    # 1. Chercher le contexte avec embeddings Ollama
    context = self.search_context(message, limit=5)

    # 2. Générer la réponse avec NVIDIA NIM
    completion = self.nvidia_client.chat.completions.create(
        model=self.config.NVIDIA_CHAT_MODEL,
        messages=[{"role": "user", "content": prompt}],
        temperature=0.2,
        top_p=0.7,
        max_tokens=1024,
        stream=False
    )

    return completion.choices[0].message.content
```

## Health Check

L'endpoint `/health` vérifie les deux services:

```json
{
  "nvidia_status": "🟢 Connecté",
  "ollama_status": "🟢 Connecté",
  "nvidia_url": "https://integrate.api.nvidia.com/v1",
  "ollama_url": "https://ollamaaccel-chatbotaccel.apps.senum.heritage.africa",
  "timestamp": "2025-11-27 09:30:00"
}
```

## Démarrage

```bash
# Vérifier les dépendances
pip install openai requests chromadb

# Lancer l'application
python "taipy_version/app_taipy copy 4.py"
```

Sortie attendue:
```
   Démarrage d'ALEX...
==================================================
🔗 Configuration Hybride:
   Chat (NVIDIA NIM): meta/llama-3.2-3b-instruct
   Embeddings (Ollama): nomic-embed-text
   Ollama URL: https://ollamaaccel-chatbotaccel.apps.senum.heritage.africa
   Répertoire surveillé: ./documents
🌐 Démarrage de l'interface...
```

## Avantages de cette architecture

### Performance
- ⚡ Embeddings rapides avec Ollama local
- ⚡ Chat optimisé avec NVIDIA cloud
- ⚡ Pas de goulot d'étranglement

### Coût
- 💰 Embeddings gratuits (Ollama)
- 💰 Chat avec quota NVIDIA
- 💰 Réduction des coûts vs 100% cloud

### Fiabilité
- 🔒 Embeddings indépendants de l'API NVIDIA
- 🔒 Fallback possible sur chaque composant
- 🔒 Double redondance

### Maintenabilité
- 🛠️ Chaque composant peut être mis à jour indépendamment
- 🛠️ Tests séparés pour embeddings et chat
- 🛠️ Configuration claire et modulaire

## Migration future

Si besoin de changer un composant:

### Remplacer Ollama par NVIDIA pour embeddings
```python
# Dans .env
NVIDIA_EMBEDDING_MODEL=nvidia/nv-embedqa-e5-v5

# Dans le code
response = self.nvidia_client.embeddings.create(
    input=[text],
    model=self.config.NVIDIA_EMBEDDING_MODEL,
    encoding_format="float",
    extra_body={"input_type": "query", "truncate": "NONE"}
)
```

### Remplacer NVIDIA par Ollama pour chat
```python
# Dans .env
OLLAMA_CHAT_MODEL=llama3

# Dans le code
response = requests.post(
    f"{self.config.OLLAMA_BASE_URL}/api/generate",
    json={"model": self.config.OLLAMA_CHAT_MODEL, "prompt": prompt}
)
```

## Monitoring

Vérifier les logs pour voir quelle API est utilisée:

```
🔄 Tentative 1/3 embedding Ollama (timeout: 30s)
✅ Embedding généré avec succès (tentative 1)
   PROMPT ENVOYÉ À NVIDIA:
   RÉPONSE NVIDIA: ...
```

## Support

En cas de problème:
1. Vérifier `/health` pour le statut des services
2. Vérifier les logs pour identifier quel service est en erreur
3. Tester individuellement Ollama et NVIDIA
