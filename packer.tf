resource "null_resource" "packer" {
  provisioner "local-exec" {
    command = <<EOT
      packer build -machine-readable ./ami/ami.pkr.hcl | tee output.txt
      ami_id=$(tail -2 output.txt | head -2 | awk 'match($0, /ami-.*/) { print substr($0, RSTART, RLENGTH) }')
      echo "Extracted AMI ID: $ami_id"
      rm -rf ami_id.txt
      echo $ami_id >> ami_id.txt
      while [ ! -s ami_id.txt ]; do
        echo "Waiting for Packer to finish, executing 30 seconds sleep"
        sleep 30
      done
      echo "Packer build finished and AMI ID generated"
    EOT

    environment = {
      PACKER_LOG = "1"
    }
  }
  depends_on = [local_file.node_public_key]
}

data "local_file" "ami_id" {
  filename   = "./ami_id.txt"
  depends_on = [null_resource.packer]
}