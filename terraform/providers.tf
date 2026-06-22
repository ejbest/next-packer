terraform {
  required_version = ">= 1.4.0"

  required_providers {
    maas = {
      source  = "canonical/maas"
      version = "~> 2.8.0"
    }
  }

  backend "s3" {
    bucket = "ejbest-terraform-state"
    key    = "terraform/next-packer/maas-machines.tfstate"
    region = "us-east-1"
  }
}
