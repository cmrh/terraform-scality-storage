# This repository is a *collection* of composite modules, published to the
# Terraform and OpenTofu registries as cmrh/storage/scality. This root module
# defines no resources on purpose — it exists so the registry can index the
# repository and surface the use-case modules underneath it as submodules.
#
# Consume a submodule with the //modules/<product>/<name> path, e.g.:
#
#   module "app_bucket" {
#     source  = "cmrh/storage/scality//modules/scality/application-bucket"
#     version = "~> 1.0"
#     # ...module inputs...
#   }
#
# See README.md for the full catalog and the Git-source (offline) form.
