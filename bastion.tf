resource "aws_instance" "bastion" {
  ami           = var.bastion_ami_id
  instance_type = "t2.micro"

  subnet_id       = aws_subnet.public_subnets[0].id
  security_groups = [aws_security_group.bastion_sg.id]

  tags = {
    Name = "BastionHost"
  }

  user_data  = <<-EOF
              #!/bin/bash
              mkdir -p /home/ec2-user/.ssh

              echo '${tls_private_key.node_key.private_key_pem}' > /home/ec2-user/.ssh/node_key.pem
              chmod 600 /home/ec2-user/.ssh/node_key.pem

              echo '${tls_private_key.bastion_key.public_key_openssh}' > /home/ec2-user/.ssh/authorized_keys
              chmod 600 /home/ec2-user/.ssh/authorized_keys
              EOF
  depends_on = [local_file.bastion_private_key, local_file.node_private_key]
}