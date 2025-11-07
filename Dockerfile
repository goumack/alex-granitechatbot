# Dockerfile pour ALEX - Assistant IA d'Accel Tech
FROM python:3.11-slim

# Métadonnées
LABEL maintainer="Accel Tech <contact@acceltech.africa>"
LABEL version="1.0"
LABEL description="ALEX - Assistant IA RAG pour Accel Tech"

# Variables d'environnement
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1
ENV FLASK_APP=app_taipy.py
ENV FLASK_ENV=production

# Répertoire de travail
WORKDIR /app

# Créer un utilisateur non-root pour la sécurité
RUN groupadd -r alex && useradd -r -g alex alex

# Installer les dépendances système
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    && rm -rf /var/lib/apt/lists/*

# Copier requirements et installer les dépendances Python
COPY taipy_version/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copier le code source
COPY taipy_version/ .

# Créer les répertoires nécessaires
RUN mkdir -p /app/documents /app/chroma_db /app/logs

# Changer la propriété vers l'utilisateur alex
RUN chown -R alex:alex /app

# Passer à l'utilisateur non-root
USER alex

# Exposer le port
EXPOSE 8505

# Vérification de santé
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD python -c "import requests; requests.get('http://localhost:8505/health', timeout=5)"

# Point d'entrée
CMD ["python", "app_taipy.py"]