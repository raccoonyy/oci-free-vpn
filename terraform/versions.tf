terraform {
  required_version = ">= 1.5.0"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 5.0"
    }
  }
}

# Auth comes from the standard OCI config (~/.oci/config).
# If your exit node lives in a dedicated account/tenancy, point
# config_file_profile at that account's profile. A single-account user can
# leave it at "DEFAULT".
provider "oci" {
  region              = var.region
  config_file_profile = var.config_file_profile
}
