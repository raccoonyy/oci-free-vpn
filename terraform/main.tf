# Tailscale exit node on OCI Always Free.
# An exit node only needs outbound reachability plus optional inbound UDP for
# direct (non-DERP) connections, so the networking here is deliberately minimal.

# ─── Availability Domain ─────────────────────────────────────────────

data "oci_identity_availability_domains" "ads" {
  compartment_id = var.compartment_id
}

# ─── Ubuntu 22.04 Image (arch follows var.shape) ────────────────────

data "oci_core_images" "ubuntu" {
  compartment_id           = var.compartment_id
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "22.04"
  shape                    = var.shape
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

# ─── VCN ─────────────────────────────────────────────────────────────

resource "oci_core_vcn" "exit" {
  compartment_id = var.compartment_id
  cidr_blocks    = [var.vcn_cidr]
  display_name   = "${var.instance_name}-vcn"
  dns_label      = "vpnvcn"
}

# ─── Internet Gateway ───────────────────────────────────────────────

resource "oci_core_internet_gateway" "exit" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.exit.id
  display_name   = "${var.instance_name}-igw"
  enabled        = true
}

# ─── Route Table ─────────────────────────────────────────────────────

resource "oci_core_route_table" "exit" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.exit.id
  display_name   = "${var.instance_name}-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.exit.id
  }
}

# ─── Security List ───────────────────────────────────────────────────
# Tailscale connects outbound, so no inbound is strictly required. We open
# SSH (for management) and UDP 41641 (helps direct peer connections; without
# it Tailscale still works via DERP relays, just with more latency).

resource "oci_core_security_list" "exit" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.exit.id
  display_name   = "${var.instance_name}-sl"

  # Egress: allow all — this is the exit path to the internet.
  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
    stateless   = false
  }

  # Ingress: SSH (restrict to your IP via ssh_allowed_cidr).
  ingress_security_rules {
    source    = var.ssh_allowed_cidr
    protocol  = "6" # TCP
    stateless = false

    tcp_options {
      min = 22
      max = 22
    }
  }

  # Ingress: Tailscale direct connections (WireGuard).
  ingress_security_rules {
    source    = "0.0.0.0/0"
    protocol  = "17" # UDP
    stateless = false

    udp_options {
      min = 41641
      max = 41641
    }
  }

  # Ingress: ICMP path-MTU (fragmentation needed) so PMTUD doesn't black-hole.
  ingress_security_rules {
    source    = "0.0.0.0/0"
    protocol  = "1" # ICMP
    stateless = false

    icmp_options {
      type = 3
      code = 4
    }
  }

  # Ingress: ICMP within the VCN.
  ingress_security_rules {
    source    = var.vcn_cidr
    protocol  = "1"
    stateless = false

    icmp_options {
      type = 3
    }
  }
}

# ─── Public Subnet ───────────────────────────────────────────────────

resource "oci_core_subnet" "exit" {
  compartment_id    = var.compartment_id
  vcn_id            = oci_core_vcn.exit.id
  cidr_block        = var.subnet_cidr
  display_name      = "${var.instance_name}-subnet"
  dns_label         = "vpnsub"
  route_table_id    = oci_core_route_table.exit.id
  security_list_ids = [oci_core_security_list.exit.id]
}

# ─── Compute Instance ───────────────────────────────────────────────

resource "oci_core_instance" "exit" {
  compartment_id      = var.compartment_id
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  display_name        = var.instance_name
  shape               = var.shape

  # shape_config only applies to *.Flex shapes; E2.1.Micro is a fixed shape and
  # rejects it. Emit the block only when a Flex shape is selected.
  dynamic "shape_config" {
    for_each = can(regex("Flex$", var.shape)) ? [1] : []
    content {
      ocpus         = var.ocpus
      memory_in_gbs = var.memory_in_gbs
    }
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.exit.id
    assign_public_ip = true
    display_name     = "${var.instance_name}-vnic"

    # Exit-node traffic has source IPs outside this subnet, so the VNIC must
    # not drop packets whose src/dst isn't its own address.
    skip_source_dest_check = true
  }

  source_details {
    source_type             = "image"
    source_id               = data.oci_core_images.ubuntu.images[0].id
    boot_volume_size_in_gbs = var.boot_volume_size_in_gbs
  }

  metadata = {
    ssh_authorized_keys = file(pathexpand(var.ssh_public_key_path))
    user_data = base64encode(templatefile("${path.module}/cloud-init.yaml.tftpl", {
      ts_hostname = var.ts_hostname
      ts_authkey  = var.ts_authkey
    }))
  }

  # Don't let a newer Ubuntu image force a destroy/recreate on later applies.
  lifecycle {
    ignore_changes = [source_details[0].source_id]
  }
}
