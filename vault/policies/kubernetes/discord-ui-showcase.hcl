path "kv/data/apps/discord-ui-showcase/prod/*" {
  capabilities = ["read"]
}

path "kv/metadata/apps/discord-ui-showcase/prod/*" {
  capabilities = ["read", "list"]
}
