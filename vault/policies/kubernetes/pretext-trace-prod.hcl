path "kv/data/apps/pretext-trace/prod/ingress-basic-auth" {
  capabilities = ["read"]
}

path "kv/metadata/apps/pretext-trace/prod/ingress-basic-auth" {
  capabilities = ["read", "list"]
}

path "kv/data/apps/pretext-trace/prod/image-pull" {
  capabilities = ["read"]
}

path "kv/metadata/apps/pretext-trace/prod/image-pull" {
  capabilities = ["read", "list"]
}
