# Guide de Déploiement ALEX sur OpenShift depuis Windows

## Prérequis Windows

### 1. Installer les outils nécessaires

#### OpenShift CLI (oc)
```powershell
# Télécharger depuis: https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/
# Ou utiliser Chocolatey
choco install openshift-cli
```

#### Podman Desktop (recommandé pour Windows)
```powershell
# Télécharger depuis: https://podman-desktop.io/downloads
# Ou utiliser winget
winget install RedHat.Podman-Desktop
```

#### Git Bash (pour exécuter les scripts bash)
```powershell
# Télécharger depuis: https://git-scm.com/download/win
# Ou utiliser Chocolatey
choco install git
```

### 2. Vérifier l'installation

Ouvrir **PowerShell** ou **Git Bash**:

```powershell
# Vérifier oc
oc version

# Vérifier podman
podman --version

# Vérifier git bash
bash --version
```

## Option 1: Déploiement avec Git Bash (Recommandé)

### Étape 1: Ouvrir Git Bash

Cliquez droit dans le dossier du projet → "Git Bash Here"

### Étape 2: Rendre le script exécutable

```bash
chmod +x deploy-alex.sh
```

### Étape 3: Se connecter à OpenShift

```bash
oc login --token=<VOTRE_TOKEN> --server=https://api.senum.heritage.africa:6443
```

### Étape 4: Lancer le déploiement

```bash
./deploy-alex.sh deploy
```

## Option 2: Déploiement avec PowerShell

### Script PowerShell pour Windows

Créez un fichier `deploy-alex.ps1` avec le contenu suivant:

```powershell
# Script de déploiement ALEX pour Windows PowerShell
# Version: 1.0

$ErrorActionPreference = "Stop"

# Configuration
$NAMESPACE = "alex-granitechatbot"
$IMAGE_NAME = "alex-optimized"
$REGISTRY = "image-registry.openshift-image-registry.svc:5000"
$FULL_IMAGE = "$REGISTRY/$NAMESPACE/${IMAGE_NAME}:latest"

# Fonctions de log avec couleurs
function Log-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Blue
}

function Log-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Log-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Log-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

# Vérifier la connexion OpenShift
function Check-OCLogin {
    Log-Info "Vérification de la connexion OpenShift..."
    try {
        $user = oc whoami
        Log-Success "Connecté en tant que: $user"
    }
    catch {
        Log-Error "Vous n'êtes pas connecté à OpenShift. Utilisez: oc login"
        exit 1
    }
}

# Créer le namespace
function Setup-Namespace {
    Log-Info "Configuration du namespace: $NAMESPACE"

    $projectExists = oc get project $NAMESPACE 2>&1
    if ($LASTEXITCODE -eq 0) {
        Log-Info "Le namespace $NAMESPACE existe déjà"
        oc project $NAMESPACE
    }
    else {
        Log-Info "Création du namespace $NAMESPACE"
        oc new-project $NAMESPACE
    }

    Log-Success "Namespace configuré: $NAMESPACE"
}

# Créer le secret NVIDIA
function Create-NvidiaSecret {
    Log-Info "Configuration du secret NVIDIA API Key..."

    # Charger le fichier .env
    if (-not (Test-Path ".env")) {
        Log-Error "Fichier .env introuvable"
        exit 1
    }

    # Lire la clé API depuis .env
    $envContent = Get-Content ".env"
    $nvidiaKey = ($envContent | Where-Object { $_ -match "^NVIDIA_API_KEY=" }) -replace "^NVIDIA_API_KEY=", ""

    if ([string]::IsNullOrEmpty($nvidiaKey)) {
        Log-Error "NVIDIA_API_KEY non trouvée dans .env"
        exit 1
    }

    # Supprimer le secret s'il existe
    $secretExists = oc get secret alex-nvidia-secret 2>&1
    if ($LASTEXITCODE -eq 0) {
        Log-Warning "Le secret existe déjà, suppression..."
        oc delete secret alex-nvidia-secret
    }

    # Créer le secret
    oc create secret generic alex-nvidia-secret --from-literal=NVIDIA_API_KEY="$nvidiaKey"
    Log-Success "Secret NVIDIA créé avec succès"
}

# Créer les ressources de stockage
function Create-Storage {
    Log-Info "Création des ressources de stockage..."

    $pvcExists = oc get pvc alex-documents-pvc 2>&1
    if ($LASTEXITCODE -eq 0) {
        Log-Warning "Les PVCs existent déjà, passage..."
    }
    else {
        oc apply -f openshift/storage.yaml
        Log-Success "PVCs créés avec succès"

        # Attendre le binding
        Log-Info "Attente du binding des PVCs..."
        $timeout = 60
        while ($timeout -gt 0) {
            $doc_status = oc get pvc alex-documents-pvc -o jsonpath='{.status.phase}'
            $chroma_status = oc get pvc alex-chroma-pvc -o jsonpath='{.status.phase}'

            if (($doc_status -eq "Bound") -and ($chroma_status -eq "Bound")) {
                Log-Success "PVCs sont bound"
                break
            }

            Start-Sleep -Seconds 2
            $timeout -= 2
        }

        if ($timeout -le 0) {
            Log-Error "Timeout: Les PVCs ne sont pas bound"
            exit 1
        }
    }
}

# Créer la ConfigMap
function Create-ConfigMap {
    Log-Info "Création de la ConfigMap..."

    $configMapExists = oc get configmap alex-config 2>&1
    if ($LASTEXITCODE -eq 0) {
        Log-Warning "ConfigMap existe déjà, mise à jour..."
        oc apply -f openshift/configmap.yaml
    }
    else {
        oc create -f openshift/configmap.yaml
    }

    Log-Success "ConfigMap créée/mise à jour"
}

# Construire et pousser l'image
function Build-And-Push-Image {
    Log-Info "Construction de l'image Docker..."

    # Construction
    podman build -t "${IMAGE_NAME}:latest" -f Dockerfile .
    if ($LASTEXITCODE -ne 0) {
        Log-Error "Échec de la construction de l'image"
        exit 1
    }
    Log-Success "Image construite avec succès"

    # Connexion au registry
    Log-Info "Connexion au registry OpenShift..."
    $token = oc whoami -t
    $user = oc whoami
    echo $token | podman login -u $user --password-stdin $REGISTRY --tls-verify=false

    # Tag
    Log-Info "Tag de l'image..."
    podman tag "${IMAGE_NAME}:latest" $FULL_IMAGE

    # Push
    Log-Info "Push de l'image vers le registry..."
    podman push $FULL_IMAGE --tls-verify=false
    if ($LASTEXITCODE -ne 0) {
        Log-Error "Échec du push de l'image"
        exit 1
    }
    Log-Success "Image poussée avec succès"
}

# Déployer l'application
function Deploy-Application {
    Log-Info "Déploiement de l'application..."

    $deploymentExists = oc get deployment alex-deployment 2>&1
    if ($LASTEXITCODE -eq 0) {
        Log-Warning "Deployment existe déjà, mise à jour..."
        oc apply -f openshift/deployment.yaml
        oc rollout restart deployment/alex-deployment
    }
    else {
        oc create -f openshift/deployment.yaml
    }

    Log-Success "Application déployée"

    # Attendre le rollout
    Log-Info "Attente de la disponibilité..."
    oc rollout status deployment/alex-deployment --timeout=5m
    Log-Success "Rollout terminé"
}

# Créer le Service et la Route
function Create-Service-Route {
    Log-Info "Création du Service et de la Route..."

    $serviceExists = oc get service alex-service 2>&1
    if ($LASTEXITCODE -eq 0) {
        oc apply -f openshift/service-route.yaml
    }
    else {
        oc create -f openshift/service-route.yaml
    }

    Log-Success "Service et Route créés"
}

# Afficher les informations
function Show-Info {
    Write-Host ""
    Log-Success "=========================================="
    Log-Success "  DÉPLOIEMENT RÉUSSI!"
    Log-Success "=========================================="
    Write-Host ""

    $routeHost = oc get route alex-route -o jsonpath='{.spec.host}'
    Write-Host "URL de l'application: https://$routeHost" -ForegroundColor Green
    Write-Host ""

    Write-Host "Status des pods:" -ForegroundColor Blue
    oc get pods -l app=alex
    Write-Host ""

    Log-Info "Pour voir les logs: oc logs -f deployment/alex-deployment"
    Log-Info "Pour tester: curl -k https://$routeHost/health"
}

# Déploiement complet
function Full-Deployment {
    Log-Info "Démarrage du déploiement complet..."
    Check-OCLogin
    Setup-Namespace
    Create-NvidiaSecret
    Create-Storage
    Create-ConfigMap
    Build-And-Push-Image
    Deploy-Application
    Create-Service-Route
    Show-Info
}

# Menu interactif
function Show-Menu {
    Clear-Host
    Write-Host "=========================================="
    Write-Host "  ALEX - Déploiement OpenShift"
    Write-Host "=========================================="
    Write-Host ""
    Write-Host "1. Déploiement complet"
    Write-Host "2. Mise à jour de l'application"
    Write-Host "3. Mise à jour de la configuration"
    Write-Host "4. Redémarrer l'application"
    Write-Host "5. Afficher les informations"
    Write-Host "6. Voir les logs"
    Write-Host "0. Quitter"
    Write-Host ""
}

# Script principal
if ($args.Count -eq 0) {
    # Mode interactif
    while ($true) {
        Show-Menu
        $choice = Read-Host "Choisissez une option"

        switch ($choice) {
            "1" { Full-Deployment; Read-Host "Appuyez sur Entrée pour continuer" }
            "2" {
                Check-OCLogin
                oc project $NAMESPACE
                Build-And-Push-Image
                Deploy-Application
                Show-Info
                Read-Host "Appuyez sur Entrée pour continuer"
            }
            "3" {
                Check-OCLogin
                oc project $NAMESPACE
                Create-NvidiaSecret
                Create-ConfigMap
                oc rollout restart deployment/alex-deployment
                Log-Success "Configuration mise à jour"
                Read-Host "Appuyez sur Entrée pour continuer"
            }
            "4" {
                Check-OCLogin
                oc project $NAMESPACE
                oc rollout restart deployment/alex-deployment
                oc rollout status deployment/alex-deployment
                Log-Success "Application redémarrée"
                Read-Host "Appuyez sur Entrée pour continuer"
            }
            "5" {
                Check-OCLogin
                oc project $NAMESPACE
                Show-Info
                Read-Host "Appuyez sur Entrée pour continuer"
            }
            "6" {
                Check-OCLogin
                oc project $NAMESPACE
                oc logs -f deployment/alex-deployment
            }
            "0" {
                Log-Info "Au revoir!"
                exit 0
            }
            default { Log-Error "Option invalide" }
        }
    }
}
else {
    # Mode CLI
    switch ($args[0]) {
        "deploy" { Full-Deployment }
        "update" {
            Check-OCLogin
            oc project $NAMESPACE
            Build-And-Push-Image
            Deploy-Application
            Show-Info
        }
        "config" {
            Check-OCLogin
            oc project $NAMESPACE
            Create-NvidiaSecret
            Create-ConfigMap
            oc rollout restart deployment/alex-deployment
        }
        "restart" {
            Check-OCLogin
            oc project $NAMESPACE
            oc rollout restart deployment/alex-deployment
        }
        "info" {
            Check-OCLogin
            oc project $NAMESPACE
            Show-Info
        }
        "logs" {
            Check-OCLogin
            oc project $NAMESPACE
            oc logs -f deployment/alex-deployment
        }
        default {
            Write-Host "Usage: .\deploy-alex.ps1 [deploy|update|config|restart|info|logs]"
        }
    }
}
```

### Utilisation du script PowerShell

```powershell
# Ouvrir PowerShell en tant qu'administrateur dans le dossier du projet

# Se connecter à OpenShift
oc login --token=<VOTRE_TOKEN> --server=https://api.senum.heritage.africa:6443

# Lancer le déploiement
.\deploy-alex.ps1 deploy

# Ou mode interactif
.\deploy-alex.ps1
```

## Commandes PowerShell utiles

### Vérifier les pods
```powershell
oc get pods -l app=alex
```

### Voir les logs
```powershell
oc logs -f deployment/alex-deployment
```

### Copier un fichier vers le pod
```powershell
oc cp mon-document.pdf deployment/alex-deployment:/app/documents/
```

### Tester l'application
```powershell
$url = oc get route alex-route -o jsonpath='{.spec.host}'
curl -k "https://$url/health"
```

### Se connecter au pod
```powershell
oc rsh deployment/alex-deployment
```

## Troubleshooting Windows

### Erreur "podman: command not found"

Si podman n'est pas reconnu après l'installation:

1. Redémarrer PowerShell
2. Vérifier la variable PATH:
   ```powershell
   $env:Path
   ```
3. Ajouter manuellement le chemin de Podman si nécessaire:
   ```powershell
   $env:Path += ";C:\Program Files\RedHat\Podman"
   ```

### Erreur de certificat TLS

```powershell
# Utiliser --tls-verify=false pour les registries internes
podman push image-registry.openshift-image-registry.svc:5000/alex-granitechatbot/alex-optimized:latest --tls-verify=false
```

### Erreur de permissions PowerShell

Si vous obtenez une erreur de script non signé:

```powershell
# Autoriser l'exécution de scripts (en tant qu'admin)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Problème avec Git Bash et les chemins Windows

Si vous utilisez Git Bash, convertir les chemins Windows:

```bash
# Au lieu de C:\Users\...
# Utiliser /c/Users/...
cd /c/Users/baye.niang/Desktop/Projets\ et\ realisations/ALEX
```

## Notes importantes pour Windows

1. **Antivirus**: Certains antivirus peuvent bloquer podman. Ajoutez une exception si nécessaire.

2. **WSL2**: Si vous utilisez Podman Desktop, il utilise WSL2. Assurez-vous que WSL2 est installé:
   ```powershell
   wsl --install
   ```

3. **Chemins de fichiers**: Utilisez des guillemets pour les chemins avec espaces:
   ```powershell
   cd "C:\Users\baye.niang\Desktop\Projets et realisations\ALEX"
   ```

4. **Line endings**: Assurez-vous que Git n'a pas converti les line endings des scripts bash:
   ```powershell
   git config core.autocrlf input
   ```

## Support

Pour plus de détails:
- [Guide de Déploiement Complet](GUIDE_DEPLOIEMENT.md)
- [Guide de Démarrage Rapide](QUICKSTART.md)

## Contact

**Accel Tech**
- Email: contact@acceltech.africa
