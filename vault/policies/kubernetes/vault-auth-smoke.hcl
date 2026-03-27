path "kv/data/apps/vault-auth-smoke/dev/*" {
  capabilities = ["read"]
}

path "kv/metadata/apps/vault-auth-smoke/dev/*" {
  capabilities = ["read", "list"]
}
