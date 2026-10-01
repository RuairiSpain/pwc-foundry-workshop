"""Create a Foundry memory store for the hosted agent.

Run by the postprovision hook. Idempotent: an existing store of the same name is
reused rather than recreated.
"""
import os
import sys


def build_store_spec(name: str, chat_deployment: str, embedding_deployment: str) -> dict:
    """Pure function: the memory-store payload. Unit-tested."""
    if not name:
        raise ValueError("memory store name is required")
    return {
        "name": name,
        "description": "PwC workshop agent memory - user profile facts.",
        "chatModel": {"deploymentName": chat_deployment},
        "embeddingModel": {"deploymentName": embedding_deployment},
        "scope": "user",
    }


def main(argv: list[str]) -> int:
    name = argv[1] if len(argv) > 1 else "pwc-workshop-memory"
    endpoint = os.environ.get("FOUNDRY_PROJECT_ENDPOINT")
    if not endpoint:
        print("FOUNDRY_PROJECT_ENDPOINT not set; skipping memory store creation.")
        return 0
    spec = build_store_spec(
        name,
        os.environ.get("MICROSOFT_FOUNDRY_MODEL_DEPLOYMENT_NAME", "gpt-5.4-mini"),
        os.environ.get("EMBEDDING_DEPLOYMENT_NAME", "text-embedding-3-small"),
    )
    try:
        from azure.ai.projects import AIProjectClient
        from azure.identity import DefaultAzureCredential
    except ImportError:
        print("azure-ai-projects not installed; run: pip install azure-ai-projects azure-identity")
        return 1
    client = AIProjectClient(endpoint, DefaultAzureCredential())
    existing = [s.name for s in client.beta.memory_stores.list()]
    if name in existing:
        print(f"memory store '{name}' already exists - reusing")
        return 0
    client.beta.memory_stores.create(**spec)
    print(f"created memory store '{name}'")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
