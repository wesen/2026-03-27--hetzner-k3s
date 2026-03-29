path "kv/data/infra/mysql/*" {
  capabilities = ["read"]
}

path "kv/metadata/infra/mysql/*" {
  capabilities = ["read", "list"]
}

path "kv/data/infra/backups/object-storage" {
  capabilities = ["read"]
}
