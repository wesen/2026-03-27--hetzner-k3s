provider "hcloud" {
  token = var.hcloud_token
}

locals {
  app_host              = "${var.app_subdomain}.${var.base_domain}"
  argocd_host           = var.argocd_host
  postgres_user_b64     = base64encode(var.postgres_user)
  postgres_password_b64 = base64encode(var.postgres_password)
  postgres_db_b64       = base64encode(var.postgres_db)
}

resource "hcloud_ssh_key" "default" {
  name       = "${var.server_name}-key"
  public_key = var.ssh_public_key
}

resource "hcloud_firewall" "default" {
  name = "${var.server_name}-fw"

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "22"
    source_ips = var.admin_cidrs
  }

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "80"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "443"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  dynamic "rule" {
    for_each = var.allow_kube_api ? [1] : []
    content {
      direction  = "in"
      protocol   = "tcp"
      port       = "6443"
      source_ips = var.admin_cidrs
    }
  }
}

resource "hcloud_server" "node" {
  name        = var.server_name
  server_type = var.server_type
  image       = var.server_image
  location    = var.location

  ssh_keys     = [hcloud_ssh_key.default.id]
  firewall_ids = [hcloud_firewall.default.id]

  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
  }

  labels = {
    role  = "k3s"
    stack = "argocd-demo"
  }

  user_data = templatefile("${path.module}/cloud-init.yaml.tftpl", {
    repo_url              = var.repo_url
    repo_revision         = var.repo_revision
    chart_path            = var.chart_path
    app_namespace         = var.app_namespace
    db_secret_name        = var.db_secret_name
    postgres_user_b64     = local.postgres_user_b64
    postgres_password_b64 = local.postgres_password_b64
    postgres_db_b64       = local.postgres_db_b64
    app_host              = local.app_host
    argocd_host           = local.argocd_host
    acme_email            = var.acme_email
    acme_server           = var.acme_server
    k3s_version           = var.k3s_version
    cert_manager_version  = var.cert_manager_version
    argocd_install_url    = var.argocd_install_url
    app_image_repository  = var.app_image_repository
    app_image_tag         = var.app_image_tag
  })
}
