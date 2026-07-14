# ─────────────────────────────────────────────────────────────────────
# You MUST set these (see terraform.tfvars.example)
# ─────────────────────────────────────────────────────────────────────

variable "compartment_id" {
  description = "OCI Compartment OCID (usually your tenancy OCID for a personal account)"
  type        = string
}

variable "region" {
  description = <<-EOT
    OCI region. This MUST be your tenancy's Home Region — Always Free
    resources only exist there, and the home region is permanent.
    Examples: us-ashburn-1, us-phoenix-1, us-sanjose-1.
  EOT
  type        = string
  default     = "us-ashburn-1"
}

variable "ts_authkey" {
  description = <<-EOT
    Tailscale auth key used once at first boot to join the tailnet.
    Use an ephemeral, pre-authorized, reusable key (tag it, e.g. tag:exit-node):
    https://login.tailscale.com/admin/settings/keys
    Never commit it: set it in terraform.tfvars (gitignored) or via
    `export TF_VAR_ts_authkey=tskey-auth-...`.
  EOT
  type        = string
  sensitive   = true
}

variable "ssh_allowed_cidr" {
  description = "CIDR allowed to SSH in for management. Set this to YOUR_IP/32."
  type        = string
  default     = "0.0.0.0/0"
}

# ─────────────────────────────────────────────────────────────────────
# Sensible defaults — override only if you need to
# ─────────────────────────────────────────────────────────────────────

variable "config_file_profile" {
  description = "Profile name in ~/.oci/config. Use DEFAULT for a single account."
  type        = string
  default     = "DEFAULT"
}

variable "shape" {
  description = <<-EOT
    Compute shape. Default VM.Standard.E2.1.Micro (x86, 1 OCPU / 1 GB, fixed) is
    chosen because ARM (VM.Standard.A1.Flex) is chronically "Out of host
    capacity" in popular regions. Micro is plenty for a packet-forwarding exit
    node. If you want to try ARM, set shape = "VM.Standard.A1.Flex" and adjust
    ocpus / memory_in_gbs below.
  EOT
  type        = string
  default     = "VM.Standard.E2.1.Micro"
}

variable "ocpus" {
  description = "OCPUs — only used for *.Flex shapes (ignored for E2.1.Micro)"
  type        = number
  default     = 1
}

variable "memory_in_gbs" {
  description = "Memory in GB — only used for *.Flex shapes (ignored for E2.1.Micro)"
  type        = number
  default     = 6
}

variable "ssh_public_key_path" {
  description = "Path to the SSH public key added to the instance"
  type        = string
  default     = "~/.ssh/oci-vpn.pub"
}

variable "instance_name" {
  description = "Compute instance display name"
  type        = string
  default     = "free-vpn-exit"
}

variable "ts_hostname" {
  description = "Tailscale node hostname advertised to the tailnet"
  type        = string
  default     = "oci-vpn-exit"
}

variable "boot_volume_size_in_gbs" {
  description = "Boot volume size in GB (Always Free: up to 200 total)"
  type        = number
  default     = 50
}

variable "vcn_cidr" {
  description = "VCN CIDR block"
  type        = string
  default     = "10.30.0.0/16"
}

variable "subnet_cidr" {
  description = "Public subnet CIDR block"
  type        = string
  default     = "10.30.1.0/24"
}
