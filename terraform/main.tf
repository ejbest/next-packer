# One-time MAAS machine registration for HP bare metal servers.
# Run this ONCE when setting up new hardware or after wiping MAAS entirely.
# The 1of3 pipeline (next-base-baremetal) assumes these machines already exist
# in MAAS and are Ready — it only does deploy/release cycles, never commission.

# ─────────────────────────────────────────────────────────────────────────────
# Blue HP Server — HP Server 1 (192.168.3.120)
# Power: smart-plug-maas plugB (192.168.4.3)
# MAAS: 192.168.3.91:5240
# ─────────────────────────────────────────────────────────────────────────────
provider "maas" {
  alias   = "blue"
  api_key = var.blue_maas_api_key
  api_url = "http://192.168.3.91:5240/MAAS"
}

resource "maas_machine" "blue" {
  provider        = maas.blue
  hostname        = "blue"
  pxe_mac_address = "e4:e7:49:39:8c:d2"
  power_type      = "webhook"
  power_parameters = jsonencode({
    power_on_uri    = "http://192.168.2.97:5005/kasa/plug/plugB/on"
    power_off_uri   = "http://192.168.2.97:5005/kasa/plug/plugB/off"
    power_query_uri = "http://192.168.2.97:5005/kasa/plug/plugB/status"
  })
  zone = "default"
  pool = "default"

  lifecycle {
    ignore_changes = [hostname]
  }

  timeouts {
    create = "60m"
  }
}

resource "maas_network_interface_link" "blue_pxe" {
  provider          = maas.blue
  machine           = maas_machine.blue.id
  network_interface = "e4:e7:49:39:8c:d2"
  subnet            = "192.168.3.0/24"
  mode              = "STATIC"
  ip_address        = "192.168.3.120"
  default_gateway   = false
}

# ─────────────────────────────────────────────────────────────────────────────
# Green HP Server — HP Server 2 (192.168.2.120)
# Power: smart-plug-maas plugA (192.168.4.2)
# MAAS: 192.168.2.91:5240
# ─────────────────────────────────────────────────────────────────────────────
provider "maas" {
  alias   = "green"
  api_key = var.green_maas_api_key
  api_url = "http://192.168.2.91:5240/MAAS"
}

resource "maas_machine" "green" {
  provider        = maas.green
  hostname        = "green"
  pxe_mac_address = "f8:b4:6a:ae:c2:25"
  power_type      = "webhook"
  power_parameters = jsonencode({
    power_on_uri    = "http://192.168.2.97:5005/kasa/plug/plugA/on"
    power_off_uri   = "http://192.168.2.97:5005/kasa/plug/plugA/off"
    power_query_uri = "http://192.168.2.97:5005/kasa/plug/plugA/status"
  })
  zone = "default"
  pool = "default"

  lifecycle {
    ignore_changes = [hostname]
  }

  timeouts {
    create = "60m"
  }
}

resource "maas_network_interface_link" "green_pxe" {
  provider          = maas.green
  machine           = maas_machine.green.id
  network_interface = "f8:b4:6a:ae:c2:25"
  subnet            = "192.168.2.0/24"
  mode              = "STATIC"
  ip_address        = "192.168.2.120"
  default_gateway   = false
}
