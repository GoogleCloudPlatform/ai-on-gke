resource "google_compute_network" "main" {
  name                    = "lexitrail-vpc-network"
  auto_create_subnetworks = false 
}

resource "google_compute_subnetwork" "main" {
  name          = "lexitrail-subnet"
  ip_cidr_range = "10.128.0.0/20"
  region        = var.region
  network       = google_compute_network.main.name
}

resource "google_compute_firewall" "game_server_allow_tcp" {
  name    = "game-server-allow-tcp"
  network = google_compute_network.main.name
  priority = 1000
  allow {
    protocol = "tcp"
    ports    = ["7000-8000"]
  }

  source_ranges = ["0.0.0.0/0"]

  target_tags   = ["game-server"]
}

resource "google_compute_firewall" "game_server_allow_udp" {
  name    = "game-server-allow-udp"
  network = google_compute_network.main.name
  priority = 1000
  allow {
    protocol = "udp"
    ports    = ["7000-8000"]
  }

  source_ranges = ["0.0.0.0/0"]

  target_tags   = ["game-server"]
}