path "kv/data/apps/hair-booking/prod/*" {
  capabilities = ["read"]
}

path "kv/metadata/apps/hair-booking/prod/*" {
  capabilities = ["read", "list"]
}
