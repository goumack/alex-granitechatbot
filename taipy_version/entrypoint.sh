#!/bin/bash
# Entrypoint pour ALEX - Désactive la vérification SSL pour Ollama

# Fixer le problème SQLite pour ChromaDB AVANT l'import de chromadb
python3 << 'PYTHON_FIX'
import sys
import pysqlite3
sys.modules['sqlite3'] = sys.modules.pop('pysqlite3')
PYTHON_FIX

# Désactiver la vérification SSL de manière globale pour Python
export PYTHONHTTPSVERIFY=0
export REQUESTS_CA_BUNDLE=""
export CURL_CA_BUNDLE=""
export SSL_CERT_FILE=""

echo "🚀 Démarrage d'ALEX avec configuration SSL désactivée pour Ollama"
echo "   PYTHONHTTPSVERIFY=0"
echo "   SQLite3 remplacé par pysqlite3"
echo ""

# Lancer l'application
exec python app_taipy.py
