"""
Script de test pour verifier l'integration NVIDIA API
"""
from openai import OpenAI
import os
from dotenv import load_dotenv
import sys

# Fix encoding for Windows
if sys.platform == "win32":
    import codecs
    sys.stdout = codecs.getwriter("utf-8")(sys.stdout.detach())

# Charger les variables d'environnement
load_dotenv()

def test_nvidia_connection():
    """Test de connexion a l'API NVIDIA"""
    print("=" * 60)
    print("TEST DE CONNEXION NVIDIA API")
    print("=" * 60)

    try:
        # Initialiser le client
        client = OpenAI(
            base_url=os.getenv("NVIDIA_BASE_URL", "https://integrate.api.nvidia.com/v1"),
            api_key=os.getenv("NVIDIA_API_KEY")
        )

        print("\n1. Test de connexion...")
        print(f"   Base URL: {os.getenv('NVIDIA_BASE_URL')}")
        print(f"   Modele Chat: {os.getenv('NVIDIA_CHAT_MODEL')}")
        print(f"   Modele Embedding: {os.getenv('NVIDIA_EMBEDDING_MODEL')}")

        # Test 1: Generation de chat
        print("\n2. Test de generation de chat...")
        completion = client.chat.completions.create(
            model=os.getenv("NVIDIA_CHAT_MODEL", "meta/llama-3.2-3b-instruct"),
            messages=[{"role": "user", "content": "Dis bonjour en francais"}],
            temperature=0.2,
            top_p=0.7,
            max_tokens=100,
            stream=False
        )

        if completion.choices and len(completion.choices) > 0:
            response = completion.choices[0].message.content
            print(f"   [OK] Reponse: {response}")
        else:
            print("   [ERREUR] Aucune reponse recue")

        # Test 2: Generation d'embeddings
        print("\n3. Test de generation d'embeddings...")
        embedding_response = client.embeddings.create(
            input=["Ceci est un test"],
            model=os.getenv("NVIDIA_EMBEDDING_MODEL", "nvidia/nv-embedqa-e5-v5"),
            encoding_format="float",
            extra_body={"input_type": "query", "truncate": "NONE"}
        )

        if embedding_response.data and len(embedding_response.data) > 0:
            embedding = embedding_response.data[0].embedding
            print(f"   [OK] Embedding genere: {len(embedding)} dimensions")
            print(f"   Premiers elements: {embedding[:5]}")
        else:
            print("   [ERREUR] Aucun embedding genere")

        # Test 3: Streaming
        print("\n4. Test de streaming...")
        print("   Reponse en streaming: ", end="")
        completion_stream = client.chat.completions.create(
            model=os.getenv("NVIDIA_CHAT_MODEL", "meta/llama-3.2-3b-instruct"),
            messages=[{"role": "user", "content": "Compte de 1 a 5"}],
            temperature=0.2,
            top_p=0.7,
            max_tokens=50,
            stream=True
        )

        for chunk in completion_stream:
            if chunk.choices[0].delta.content is not None:
                print(chunk.choices[0].delta.content, end="", flush=True)

        print("\n\n" + "=" * 60)
        print("[OK] TOUS LES TESTS SONT REUSSIS!")
        print("=" * 60)

    except Exception as e:
        print(f"\n[ERREUR]: {e}")
        print("\nVerifiez:")
        print("1. Que votre cle API NVIDIA est valide")
        print("2. Que vous avez installe le package openai: pip install openai")
        print("3. Que le fichier .env contient les bonnes valeurs")

if __name__ == "__main__":
    test_nvidia_connection()
