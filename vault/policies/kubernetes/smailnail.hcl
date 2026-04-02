path "kv/data/apps/smailnail/prod/*" {
  capabilities = ["read"]
}

path "kv/metadata/apps/smailnail/prod/*" {
  capabilities = ["read", "list"]
}
