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

# Installer les dépendances système et compiler SQLite 3.35+
RUN dnf install -y gcc gcc-c++ python3-devel wget tar make && \
    # Compiler SQLite 3.45.0 pour compatibilité ChromaDB
    cd /tmp && \
    wget https://www.sqlite.org/2024/sqlite-autoconf-3450000.tar.gz && \
    tar xzf sqlite-autoconf-3450000.tar.gz && \
    cd sqlite-autoconf-3450000 && \
    ./configure --prefix=/usr/local && \
    make && make install && \
    # Mettre à jour le path et les libs
    echo '/usr/local/lib' > /etc/ld.so.conf.d/sqlite.conf && \
    ldconfig && \
    # Nettoyer
    cd / && rm -rf /tmp/sqlite-autoconf-* && \
    dnf clean all

# Copier requirements et installer les dépendances Python
COPY taipy_version/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copier le code source
COPY taipy_version/ .

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

# Point d'entrée
CMD ["python", "app_taipy.py"]