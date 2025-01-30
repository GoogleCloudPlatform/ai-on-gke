locals {
  zone_to_region = jsondecode(file("zone_to_region.json"))
  region = try(local.zone_to_region[var.a3_mega_zone], null)
}
