locals {
  zone_to_region = jsondecode(file("zone_to_region.json"))
  a3_mega_region = try(local.zone_to_region[var.a3_mega_zone], null)
  a3_ultra_region = try(local.zone_to_region[var.a3_ultra_zone], null)
  region = local.a3_mega_region == null? local.a3_ultra_region : local.a3_mega_region
  zone = local.a3_mega_region == null? var.a3_ultra_zone : var.a3_mega_zone
}
