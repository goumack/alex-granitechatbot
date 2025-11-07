#!/bin/bash

# Script de déploiement automatisé ALEX sur OpenShift
# Usage: ./deploy.sh [dev|prod]

set -e

# Configuration
PROJECT_NAME=${1:-alex-prod}
ENVIRONMENT=${2:-prod}
IMAGE_NAME="alex"

echo "🚀 Déploiement d'ALEX sur OpenShift"
echo "Projet: $PROJECT_NAME"
echo "Environnement: $ENVIRONMENT"
echo "=================================="

# Vérifier que oc est connecté
if ! oc whoami &> /dev/null; then
    echo "❌ Erreur: Vous devez être connecté à OpenShift (oc login)"
    exit 1
fi

# Créer le projet si nécessaire
echo "📂 Vérification du projet OpenShift..."
if ! oc get project $PROJECT_NAME &> /dev/null; then
    echo "Création du projet $PROJECT_NAME..."
    oc new-project $PROJECT_NAME --display-name="ALEX Assistant IA" --description="Assistant IA RAG d'Accel Tech"
else
    echo "Projet $PROJECT_NAME existe déjà"
    oc project $PROJECT_NAME
fi

# Build de l'image
echo "🔨 Construction de l'image Docker..."
if oc get bc $IMAGE_NAME &> /dev/null; then
    echo "BuildConfig existe, démarrage d'un nouveau build..."
    oc start-build $IMAGE_NAME --from-dir=./taipy_version --follow
else
    echo "Création du BuildConfig..."
    oc new-build --dockerfile="$(cat Dockerfile)" --name=$IMAGE_NAME
    oc start-build $IMAGE_NAME --from-dir=./taipy_version --follow
fi

# Attendre que l'image soit prête
echo "⏳ Attente de la disponibilité de l'image..."
oc wait --for=condition=Complete build/$IMAGE_NAME-1 --timeout=600s

# Déploiement des ressources
echo "📦 Déploiement des ressources Kubernetes..."

# ConfigMap
echo "Applying ConfigMap..."
oc apply -f openshift/configmap.yaml

# Storage
echo "Applying Storage..."
oc apply -f openshift/storage.yaml

# Attendre que les PVC soient bound
echo "⏳ Attente des volumes..."
oc wait --for=condition=Bound pvc/alex-documents-pvc --timeout=120s
oc wait --for=condition=Bound pvc/alex-chroma-pvc --timeout=120s

# Déploiement
echo "Applying Deployment..."
# Mettre à jour l'image dans le deployment
sed "s|image: alex:latest|image: image-registry.openshift-image-registry.svc:5000/$PROJECT_NAME/$IMAGE_NAME:latest|g" openshift/deployment.yaml | oc apply -f -

# Service et Route
echo "Applying Service and Route..."
oc apply -f openshift/service-route.yaml

# Attendre que le déploiement soit prêt
echo "⏳ Attente du déploiement..."
oc rollout status deployment/alex-deployment --timeout=300s

# Vérifications
echo "✅ Vérifications post-déploiement..."

# Attendre que le pod soit prêt
oc wait --for=condition=Ready pod -l app=alex --timeout=180s

# Obtenir l'URL
ROUTE_HOST=$(oc get route alex-route -o jsonpath='{.spec.host}')
echo "🌐 ALEX est accessible à: https://$ROUTE_HOST"

# Test de santé
echo "🔍 Test de santé..."
if curl -f -s "https://$ROUTE_HOST/health" > /dev/null; then
    echo "✅ Service ALEX opérationnel!"
else
    echo "⚠️ Attention: Le service ne répond pas encore (peut prendre quelques minutes)"
fi

# Afficher les informations utiles
echo ""
echo "📋 Informations de déploiement:"
echo "  URL principale: https://$ROUTE_HOST"
echo "  Health check: https://$ROUTE_HOST/health"
echo "  Status API: https://$ROUTE_HOST/status"
echo ""
echo "🔧 Commandes utiles:"
echo "  Logs: oc logs -f deployment/alex-deployment"
echo "  Status: oc get pods -l app=alex"
echo "  Redémarrer: oc rollout restart deployment/alex-deployment"
echo ""

# Test rapide de l'API
echo "🧪 Test rapide de l'API de chat..."
if curl -s -X POST "https://$ROUTE_HOST/chat" \
   -H "Content-Type: application/json" \
   -d '{"message":"bonjour"}' | grep -q "response"; then
    echo "✅ API de chat fonctionnelle!"
else
    echo "⚠️ API de chat non testable (normal si pas encore de documents indexés)"
fi

echo ""
echo "🎉 Déploiement terminé avec succès!"
echo "📝 Consultez DEPLOY.md pour les instructions détaillées de maintenance"