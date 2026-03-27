path "kv/data/apps/vso-smoke/dev/*" {
  capabilities = ["read"]
}

path "kv/metadata/apps/vso-smoke/dev/*" {
  capabilities = ["read", "list"]
}
