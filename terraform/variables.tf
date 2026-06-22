variable "blue_maas_api_key" {
  description = "MAAS API key for blue environment (192.168.3.91)"
  type        = string
  sensitive   = true
}

variable "green_maas_api_key" {
  description = "MAAS API key for green environment (192.168.2.91)"
  type        = string
  sensitive   = true
}
