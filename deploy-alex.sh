#!/bin/bash
# Script de déploiement automatique ALEX sur OpenShift
# Auteur: Accel Tech
# Version: 1.0

set -e  # Arrêter en cas d'erreur

# Couleurs pour les logs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="alex-granitechatbot"
APP_NAME="alex"
IMAGE_NAME="alex-optimized"
REGISTRY="image-registry.openshift-image-registry.svc:5000"
FULL_IMAGE="${REGISTRY}/${NAMESPACE}/${IMAGE_NAME}:latest"

# Fonctions utilitaires
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Vérifier que oc est installé
check_oc_cli() {
    log_info "Vérification de l'installation de oc CLI..."
    if ! command -v oc &> /dev/null; then
        log_error "oc CLI n'est pas installé. Installez-le depuis: https://docs.openshift.com/container-platform/latest/cli_reference/openshift_cli/getting-started-cli.html"
        exit 1
    fi
    log_success "oc CLI est installé"
}

# Vérifier que podman est installé
check_podman() {
    log_info "Vérification de l'installation de podman..."
    if ! command -v podman &> /dev/null; then
        log_error "podman n'est pas installé. Installez-le depuis: https://podman.io/getting-started/installation"
        exit 1
    fi
    log_success "podman est installé"
}

# Vérifier la connexion OpenShift
check_oc_login() {
    log_info "Vérification de la connexion OpenShift..."
    if ! oc whoami &> /dev/null; then
        log_error "Vous n'êtes pas connecté à OpenShift. Utilisez: oc login"
        exit 1
    fi
    local user=$(oc whoami)
    log_success "Connecté en tant que: $user"
}

# Créer ou utiliser le namespace
setup_namespace() {
    log_info "Configuration du namespace: $NAMESPACE"

    if oc get project $NAMESPACE &> /dev/null; then
        log_info "Le namespace $NAMESPACE existe déjà"
        oc project $NAMESPACE
    else
        log_info "Création du namespace $NAMESPACE"
        oc new-project $NAMESPACE
    fi

    log_success "Namespace configuré: $NAMESPACE"
}

# Créer le secret NVIDIA
create_nvidia_secret() {
    log_info "Configuration du secret NVIDIA API Key..."

    # Vérifier si le fichier .env existe
    if [ ! -f ".env" ]; then
        log_error "Fichier .env introuvable. Créez-le avec NVIDIA_API_KEY=votre_clé"
        exit 1
    fi

    # Charger la clé depuis .env
    source .env

    if [ -z "$NVIDIA_API_KEY" ]; then
        log_error "NVIDIA_API_KEY n'est pas définie dans .env"
        exit 1
    fi

    # Supprimer le secret s'il existe
    if oc get secret alex-nvidia-secret &> /dev/null; then
        log_warning "Le secret existe déjà, suppression..."
        oc delete secret alex-nvidia-secret
    fi

    # Créer le secret
    oc create secret generic alex-nvidia-secret \
        --from-literal=NVIDIA_API_KEY="$NVIDIA_API_KEY"

    log_success "Secret NVIDIA créé avec succès"
}

# Créer les ressources de stockage
create_storage() {
    log_info "Création des ressources de stockage..."

    if oc get pvc alex-documents-pvc &> /dev/null; then
        log_warning "Les PVCs existent déjà, passage..."
    else
        oc apply -f openshift/storage.yaml
        log_success "PVCs créés avec succès"
    fi

    # Attendre que les PVCs soient bound
    log_info "Attente du binding des PVCs..."
    timeout=60
    while [ $timeout -gt 0 ]; do
        if oc get pvc alex-documents-pvc -o jsonpath='{.status.phase}' | grep -q "Bound" && \
           oc get pvc alex-chroma-pvc -o jsonpath='{.status.phase}' | grep -q "Bound"; then
            log_success "PVCs sont bound"
            break
        fi
        sleep 2
        timeout=$((timeout-2))
    done

    if [ $timeout -le 0 ]; then
        log_error "Timeout: Les PVCs ne sont pas bound après 60 secondes"
        exit 1
    fi
}

# Créer la ConfigMap
create_configmap() {
    log_info "Création de la ConfigMap..."

    if oc get configmap alex-config &> /dev/null; then
        log_warning "ConfigMap existe déjà, mise à jour..."
        oc apply -f openshift/configmap.yaml
    else
        oc create -f openshift/configmap.yaml
    fi

    log_success "ConfigMap créée/mise à jour avec succès"
}

# Construire et pousser l'image
build_and_push_image() {
    log_info "Construction de l'image Docker..."

    # Construction de l'image
    podman build -t ${IMAGE_NAME}:latest -f Dockerfile .
    log_success "Image construite avec succès"

    # Connexion au registry OpenShift
    log_info "Connexion au registry OpenShift..."
    podman login -u $(oc whoami) -p $(oc whoami -t) ${REGISTRY} --tls-verify=false

    # Tag de l'image
    log_info "Tag de l'image..."
    podman tag ${IMAGE_NAME}:latest ${FULL_IMAGE}

    # Push de l'image
    log_info "Push de l'image vers le registry..."
    podman push ${FULL_IMAGE} --tls-verify=false
    log_success "Image poussée avec succès: ${FULL_IMAGE}"
}

# Déployer l'application
deploy_application() {
    log_info "Déploiement de l'application..."

    if oc get deployment alex-deployment &> /dev/null; then
        log_warning "Deployment existe déjà, mise à jour..."
        oc apply -f openshift/deployment.yaml
        log_info "Redémarrage du deployment..."
        oc rollout restart deployment/alex-deployment
    else
        oc create -f openshift/deployment.yaml
    fi

    log_success "Application déployée avec succès"

    # Attendre que le rollout soit terminé
    log_info "Attente de la disponibilité de l'application..."
    oc rollout status deployment/alex-deployment --timeout=5m
    log_success "Rollout terminé avec succès"
}

# Créer le Service et la Route
create_service_route() {
    log_info "Création du Service et de la Route..."

    if oc get service alex-service &> /dev/null; then
        log_warning "Service existe déjà, mise à jour..."
        oc apply -f openshift/service-route.yaml
    else
        oc create -f openshift/service-route.yaml
    fi

    log_success "Service et Route créés/mis à jour avec succès"
}

# Afficher les informations de déploiement
show_deployment_info() {
    echo ""
    log_success "=========================================="
    log_success "  DÉPLOIEMENT RÉUSSI!"
    log_success "=========================================="
    echo ""

    log_info "Informations du déploiement:"
    echo ""

    # URL de l'application
    local route_host=$(oc get route alex-route -o jsonpath='{.spec.host}' 2>/dev/null || echo "N/A")
    echo -e "${GREEN}URL de l'application:${NC} https://${route_host}"
    echo ""

    # Status du pod
    echo -e "${BLUE}Status des pods:${NC}"
    oc get pods -l app=alex
    echo ""

    # Status du service
    echo -e "${BLUE}Status du service:${NC}"
    oc get service alex-service
    echo ""

    # Status de la route
    echo -e "${BLUE}Status de la route:${NC}"
    oc get route alex-route
    echo ""

    log_info "Pour voir les logs: oc logs -f deployment/alex-deployment"
    log_info "Pour tester l'application: curl -k https://${route_host}/health"
}

# Menu principal
show_menu() {
    echo ""
    echo "=========================================="
    echo "  ALEX - Script de déploiement OpenShift"
    echo "=========================================="
    echo ""
    echo "1) Déploiement complet (recommandé pour la première fois)"
    echo "2) Mise à jour de l'application uniquement"
    echo "3) Mise à jour de la configuration uniquement"
    echo "4) Redémarrer l'application"
    echo "5) Afficher les informations de déploiement"
    echo "6) Voir les logs"
    echo "7) Supprimer complètement l'application"
    echo "0) Quitter"
    echo ""
}

# Déploiement complet
full_deployment() {
    log_info "Démarrage du déploiement complet..."
    check_oc_cli
    check_podman
    check_oc_login
    setup_namespace
    create_nvidia_secret
    create_storage
    create_configmap
    build_and_push_image
    deploy_application
    create_service_route
    show_deployment_info
}

# Mise à jour de l'application
update_application() {
    log_info "Mise à jour de l'application..."
    check_oc_cli
    check_podman
    check_oc_login
    oc project $NAMESPACE
    build_and_push_image
    deploy_application
    show_deployment_info
}

# Mise à jour de la configuration
update_configuration() {
    log_info "Mise à jour de la configuration..."
    check_oc_cli
    check_oc_login
    oc project $NAMESPACE
    create_nvidia_secret
    create_configmap
    log_info "Redémarrage de l'application pour appliquer les changements..."
    oc rollout restart deployment/alex-deployment
    oc rollout status deployment/alex-deployment --timeout=5m
    log_success "Configuration mise à jour avec succès"
}

# Redémarrer l'application
restart_application() {
    log_info "Redémarrage de l'application..."
    check_oc_cli
    check_oc_login
    oc project $NAMESPACE
    oc rollout restart deployment/alex-deployment
    oc rollout status deployment/alex-deployment --timeout=5m
    log_success "Application redémarrée avec succès"
}

# Voir les logs
view_logs() {
    log_info "Affichage des logs..."
    check_oc_cli
    check_oc_login
    oc project $NAMESPACE
    oc logs -f deployment/alex-deployment
}

# Supprimer l'application
delete_application() {
    log_warning "⚠️  ATTENTION: Cette action va supprimer complètement l'application et toutes ses données!"
    read -p "Êtes-vous sûr? (oui/non): " confirmation

    if [ "$confirmation" = "oui" ]; then
        log_info "Suppression de l'application..."
        check_oc_cli
        check_oc_login
        oc project $NAMESPACE

        oc delete -f openshift/service-route.yaml --ignore-not-found=true
        oc delete -f openshift/deployment.yaml --ignore-not-found=true
        oc delete -f openshift/configmap.yaml --ignore-not-found=true
        oc delete secret alex-nvidia-secret --ignore-not-found=true
        oc delete -f openshift/storage.yaml --ignore-not-found=true

        log_success "Application supprimée avec succès"
    else
        log_info "Suppression annulée"
    fi
}

# Script principal
main() {
    # Si pas d'arguments, afficher le menu
    if [ $# -eq 0 ]; then
        while true; do
            show_menu
            read -p "Choisissez une option: " choice

            case $choice in
                1) full_deployment ;;
                2) update_application ;;
                3) update_configuration ;;
                4) restart_application ;;
                5) check_oc_cli && check_oc_login && oc project $NAMESPACE && show_deployment_info ;;
                6) view_logs ;;
                7) delete_application ;;
                0) log_info "Au revoir!"; exit 0 ;;
                *) log_error "Option invalide" ;;
            esac

            echo ""
            read -p "Appuyez sur Entrée pour continuer..."
        done
    else
        # Mode CLI avec arguments
        case $1 in
            deploy) full_deployment ;;
            update) update_application ;;
            config) update_configuration ;;
            restart) restart_application ;;
            info) check_oc_cli && check_oc_login && oc project $NAMESPACE && show_deployment_info ;;
            logs) view_logs ;;
            delete) delete_application ;;
            *)
                echo "Usage: $0 [deploy|update|config|restart|info|logs|delete]"
                echo "  deploy  - Déploiement complet"
                echo "  update  - Mise à jour de l'application"
                echo "  config  - Mise à jour de la configuration"
                echo "  restart - Redémarrer l'application"
                echo "  info    - Afficher les informations"
                echo "  logs    - Voir les logs"
                echo "  delete  - Supprimer l'application"
                exit 1
                ;;
        esac
    fi
}

# Exécuter le script
main "$@"
