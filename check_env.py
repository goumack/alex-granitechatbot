"""
Script pour vérifier la configuration .env
"""
import os
from pathlib import Path
from dotenv import load_dotenv

print("=" * 60)
print("VERIFICATION DE LA CONFIGURATION .env")
print("=" * 60)

# Afficher le répertoire courant
print(f"\nRépertoire courant: {os.getcwd()}")

# Chercher le fichier .env
env_files = [
    Path(".env"),
    Path(__file__).parent / ".env",
    Path(__file__).parent.parent / ".env"
]

print("\nRecherche du fichier .env:")
for env_file in env_files:
    abs_path = env_file.resolve()
    exists = abs_path.exists()
    print(f"  {'✓' if exists else '✗'} {abs_path}")
    if exists:
        print(f"    Taille: {abs_path.stat().st_size} bytes")

# Charger le .env depuis le répertoire du script
env_path = Path(__file__).parent / '.env'
if env_path.exists():
    load_dotenv(dotenv_path=env_path)
    print(f"\nConfiguration chargée depuis: {env_path}")
else:
    load_dotenv()
    print("\nConfiguration chargée avec load_dotenv() par défaut")

# Vérifier les variables NVIDIA
print("\nVariables d'environnement NVIDIA:")
nvidia_vars = [
    "NVIDIA_API_KEY",
    "NVIDIA_BASE_URL",
    "NVIDIA_CHAT_MODEL",
    "NVIDIA_EMBEDDING_MODEL"
]

for var in nvidia_vars:
    value = os.getenv(var)
    if value:
        # Masquer partiellement la clé API pour la sécurité
        if "KEY" in var:
            display_value = value[:10] + "..." + value[-10:] if len(value) > 20 else "***"
        else:
            display_value = value
        print(f"  ✓ {var}: {display_value}")
    else:
        print(f"  ✗ {var}: NON DÉFINIE")

# Tester la connexion
print("\n" + "=" * 60)
if os.getenv("NVIDIA_API_KEY"):
    print("Configuration OK - Vous pouvez démarrer l'application")
else:
    print("ERREUR: NVIDIA_API_KEY manquante!")
    print("\nActions à effectuer:")
    print("1. Vérifiez que le fichier .env existe")
    print("2. Vérifiez que NVIDIA_API_KEY est définie dans .env")
    print("3. Redémarrez l'application")
print("=" * 60)
