resource "null_resource" "wsl_kubernetes" {
  triggers = {
    kubernetes_version = var.kubernetes_version
  }

  provisioner "local-exec" {
    command = "${var.scripts_dir}/install-wsl-kubernetes.sh ${var.kubernetes_version}"
  }
}
