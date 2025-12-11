# Dockerfile pour ALEX - Assistant IA d'Accel Tech
FROM registry.redhat.io/ubi9/python-311

# Métadonnées
LABEL maintainer="Accel Tech <contact@acceltech.africa>"
LABEL version="1.0"
LABEL description="ALEX - Assistant IA RAG pour Accel Tech"

# Variables d'environnement
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1
ENV FLASK_APP=app_taipy.py
ENV FLASK_ENV=production
ENV LD_LIBRARY_PATH=/usr/local/lib:${LD_LIBRARY_PATH}
ENV PATH=/usr/local/bin:${PATH}

# Répertoire de travail
WORKDIR /app

# L'utilisateur par défaut est déjà non-root dans UBI
USER 0

# Installer les dépendances système minimales
RUN dnf install -y python3-devel sqlite sqlite-devel && \
    dnf clean all

# Copier requirements et installer les dépendances Python
COPY taipy_version/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copier le code source
COPY taipy_version/ .

# Copier le script d'entrée
COPY taipy_version/entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# Créer les répertoires nécessaires
RUN mkdir -p /app/documents /app/chroma_db /app/logs

# Changer la propriété vers l'utilisateur par défaut
RUN chown -R 1001:0 /app && chmod -R g+w /app

# Passer à l'utilisateur non-root
USER 1001

# Exposer le port
EXPOSE 8505

# Vérification de santé
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD python -c "import requests; requests.get('http://localhost:8505/health', timeout=5)"

# Point d'entrée - utiliser le script qui fixe sqlite3 AVANT l'import
CMD ["/app/entrypoint.sh"]