output "ray_uri" {
  value = data.kubernetes_service.example.status != null  && var.enable_autopilot ? "${data.kubernetes_service.example.status[0].load_balancer[0].ingress[0].ip}:8265" : ""
}