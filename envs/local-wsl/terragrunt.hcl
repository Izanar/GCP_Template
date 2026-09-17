include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../src/local-wsl"
}

inputs = {
  kubernetes_version = "v1.31.1+k3s1"
  node_port          = 30080
  scripts_dir        = "${get_terragrunt_dir()}/../../scripts"
}
