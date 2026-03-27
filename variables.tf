variable "hcloud_token" {
  description = "Hetzner Cloud API token"
  type        = string
  sensitive   = true
}

variable "ssh_public_key" {
  description = "Public SSH key that will be uploaded to Hetzner Cloud"
  type        = string
}

variable "server_name" {
  description = "Name of the Hetzner server"
  type        = string
  default     = "k3s-demo-1"
}

variable "server_type" {
  description = "Hetzner server type"
  type        = string
  default     = "cpx31"
}

variable "server_image" {
  description = "Hetzner OS image"
  type        = string
  default     = "ubuntu-24.04"
}

variable "location" {
  description = "Hetzner location"
  type        = string
  default     = "fsn1"
}

variable "admin_cidrs" {
  description = "CIDRs allowed to SSH to the server and optionally reach the Kubernetes API"
  type        = list(string)
}

variable "allow_kube_api" {
  description = "Whether to expose the Kubernetes API on 6443 to admin_cidrs"
  type        = bool
  default     = true
}

variable "repo_url" {
  description = "Git URL for this repo. Use a public repo for the simplest bootstrap. Example: https://github.com/you/hetzner-k3s-argocd-demo.git"
  type        = string
}

variable "repo_revision" {
  description = "Git branch, tag, or commit to deploy"
  type        = string
  default     = "main"
}

variable "chart_path" {
  description = "Path to the Helm chart inside the Git repo"
  type        = string
  default     = "gitops/charts/demo-stack"
}

variable "base_domain" {
  description = "Base domain for the demo app, e.g. example.com"
  type        = string
}

variable "app_subdomain" {
  description = "Subdomain for the demo app"
  type        = string
  default     = "demo"
}

variable "argocd_host" {
  description = "Optional public hostname for the Argo CD UI. Leave empty to keep it internal-only."
  type        = string
  default     = ""
}

variable "acme_email" {
  description = "Email address for Let's Encrypt ACME registration"
  type        = string
}

variable "acme_server" {
  description = "ACME directory URL. Use staging while testing if desired."
  type        = string
  default     = "https://acme-v02.api.letsencrypt.org/directory"
}

variable "app_namespace" {
  description = "Namespace for the demo application"
  type        = string
  default     = "demo"
}

variable "db_secret_name" {
  description = "Name of the Kubernetes Secret containing PostgreSQL credentials"
  type        = string
  default     = "postgres-app"
}

variable "postgres_db" {
  description = "PostgreSQL database name"
  type        = string
  default     = "demo"
}

variable "postgres_user" {
  description = "PostgreSQL username"
  type        = string
  default     = "demo"
}

variable "postgres_password" {
  description = "PostgreSQL password"
  type        = string
  sensitive   = true
}

variable "k3s_version" {
  description = "Optional pinned K3s version. Leave empty for the stable channel. Example: v1.33.3+k3s1"
  type        = string
  default     = ""
}

variable "cert_manager_version" {
  description = "Pinned cert-manager version for the static install manifest"
  type        = string
  default     = "v1.20.0"
}

variable "argocd_install_url" {
  description = "Argo CD install manifest URL. Pin this for stricter reproducibility if desired."
  type        = string
  default     = "https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml"
}

variable "app_image_repository" {
  description = "Image name for the locally built demo app image"
  type        = string
  default     = "docker.io/library/demo-go-app"
}

variable "app_image_tag" {
  description = "Tag for the locally built demo app image"
  type        = string
  default     = "1.0.0"
}
