resource "tls_private_key" "bastion_key" {
  algorithm  = "RSA"
  rsa_bits   = 2048
  depends_on = [null_resource.create_ssh_directory]
}

resource "tls_private_key" "node_key" {
  algorithm  = "RSA"
  rsa_bits   = 2048
  depends_on = [null_resource.create_ssh_directory]
}

resource "null_resource" "create_ssh_directory" {
  provisioner "local-exec" {
    command = "mkdir -p ./ssh"
  }
}

resource "local_file" "bastion_private_key" {
  content         = tls_private_key.bastion_key.private_key_pem
  filename        = "./ssh/bastion_key.pem"
  file_permission = "0600"
}

resource "local_file" "node_private_key" {
  content         = tls_private_key.node_key.private_key_pem
  filename        = "./ssh/node_key.pem"
  file_permission = "0600"
}

resource "local_file" "bastion_public_key" {
  content  = tls_private_key.bastion_key.public_key_openssh
  filename = "./ssh/bastion_key.pub"
}

resource "local_file" "node_public_key" {
  content  = tls_private_key.node_key.public_key_openssh
  filename = "./ssh/node_key.pub"
}