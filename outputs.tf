output "server_ipv4" {
  description = "Public IPv4 of the server"
  value       = hcloud_server.node.ipv4_address
}

output "server_ipv6" {
  description = "Public IPv6 network of the server"
  value       = hcloud_server.node.ipv6_address
}

output "app_url" {
  description = "Expected public URL for the demo app once DNS and TLS are ready"
  value       = "https://${local.app_host}"
}

output "ssh_command" {
  description = "SSH helper"
  value       = "ssh root@${hcloud_server.node.ipv4_address}"
}

output "cloud_init_log_hint" {
  description = "Watch bootstrap progress"
  value       = "ssh root@${hcloud_server.node.ipv4_address} 'tail -f /var/log/cloud-init-output.log'"
}
