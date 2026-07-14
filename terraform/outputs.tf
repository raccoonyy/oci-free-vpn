output "instance_public_ip" {
  description = "Public (egress) IP of the exit node"
  value       = oci_core_instance.exit.public_ip
}

output "instance_id" {
  description = "OCID of the exit-node instance"
  value       = oci_core_instance.exit.id
}

output "ssh_command" {
  description = "SSH command to manage the instance"
  value       = "ssh -i ${replace(var.ssh_public_key_path, ".pub", "")} ubuntu@${oci_core_instance.exit.public_ip}"
}

output "vcn_id" {
  description = "OCID of the VCN"
  value       = oci_core_vcn.exit.id
}
