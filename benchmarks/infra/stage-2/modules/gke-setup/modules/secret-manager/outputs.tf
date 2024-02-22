output "created_resources" {
  description = "IDs of the resources created, if any."
  value = {
    secret = module.secret-manager.ids
  }
}