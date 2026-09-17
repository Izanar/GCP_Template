variable "kubernetes_version" {
  description = "k3s version to install, e.g. v1.31.1+k3s1"
  type        = string
  default     = "v1.31.1+k3s1"
}

variable "node_port" {
  description = "NodePort for the nginx service"
  type        = number
  default     = 30080
}

variable "scripts_dir" {
  description = "Absolute path to the repository scripts directory"
  type        = string
}
