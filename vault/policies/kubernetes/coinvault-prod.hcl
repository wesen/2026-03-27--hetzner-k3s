path "kv/data/apps/coinvault/prod/*" {
  capabilities = ["read"]
}

path "kv/metadata/apps/coinvault/prod/*" {
  capabilities = ["read", "list"]
}
