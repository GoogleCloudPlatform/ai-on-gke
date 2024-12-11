resource "helm_release" "open_match" {
  name       = "open-match"
  repository = "https://open-match.dev/chart/stable"
  chart      = "open-match"
  namespace  = "open-match"
  create_namespace = true
  wait = true

  set {
    name  = "open-match-customize.enabled"
    value = "true"
  }

  set {
    name  = "open-match-customize.evaluator.enabled"
    value = "true"
  }

  set {
    name  = "open-match-override.enabled"
    value = "true"
  }

  depends_on = [
    google_container_cluster.autopilot_cluster
  ]
}