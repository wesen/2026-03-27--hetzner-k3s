path "kv/data/infra/backups/object-storage" {
  capabilities = ["read"]
}

path "sys/storage/raft/snapshot" {
  capabilities = ["read", "sudo"]
}
