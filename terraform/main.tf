provider "aws" {
  access_key = var.AWS_ACCESS_KEY
  secret_key = var.AWS_SECRET_KEY
  region = var.AWS_REGION
}

resource "aws_default_vpc" "default" {
  tags = {
    Name = "Default VPC"
  }
}

data "external" "mypublicip" {
  program = ["python","mypublicip.py"]
}
output "mypublic_ip" {
  description = "List of public IP addresses assigned to the instances, if applicable"
  value       = data.external.mypublicip.result
}
## create key file
resource "tls_private_key" "keyfile" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "generated_key" {
  key_name   = "nginx"
  public_key = tls_private_key.keyfile.public_key_openssh
}

output "private_key" {
  value = tls_private_key.keyfile.private_key_pem
}

resource "local_file" "keyfile" {
  content = tls_private_key.keyfile.private_key_pem
  filename = "keyfile.pem"
  file_permission = "0400"
}

# Create the Security Group for public
resource "aws_security_group" "My_VPC_Security_Group-public" {
  name = "public-sg"
  description = "My VPC Security Group"

  # allow ingress of port 22
  ingress {
    cidr_blocks =  ["0.0.0.0/0"]
    from_port = 80
    to_port = 80
    protocol = "tcp"
  }
  ingress {
    cidr_blocks =  ["0.0.0.0/0"]
    from_port = 443
    to_port = 443
    protocol = "tcp"
  }
  ingress {
    cidr_blocks =  [aws_default_vpc.default.cidr_block]
    from_port = 0
    to_port = 65535
    protocol = "tcp"
  }
  ingress {
    cidr_blocks =  [data.external.mypublicip.result["publicip"]]
    from_port = 22
    to_port = 22
    protocol = "tcp"
  }

  # allow egress of all ports
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = [
      "0.0.0.0/0"]
  }
}

# Create the Security Group for private
resource "aws_security_group" "My_VPC_Security_Group-private" {
  name = "private-sg"
  description = "My VPC Security Group"

  # allow ingress of port 22
  ingress {
    cidr_blocks =  [aws_default_vpc.default.cidr_block]
    from_port = 0
    to_port = 65535
    protocol = "tcp"
  }
  ingress {
    cidr_blocks =  [data.external.mypublicip.result["publicip"]]
    from_port = 22
    to_port = 22
    protocol = "tcp"
  }

  # allow egress of all ports
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = [
      "0.0.0.0/0"]
  }
}

####create backend springboot application

resource "aws_instance" "spring-boot" {
  ami = "ami-0083662ba17882949"
  instance_type = "t2.small"
  key_name = aws_key_pair.generated_key.key_name
  vpc_security_group_ids = ["${aws_security_group.My_VPC_Security_Group-private.id}"]
  tags = {
    Name = "spring-boot"
  }
  provisioner "remote-exec" {
    inline = ["sudo yum -y install python"]
    connection {
      host = self.public_ip
      type        = "ssh"
      user        = "centos"
      private_key = tls_private_key.keyfile.private_key_pem
    }
  }
  provisioner "local-exec" {
    command = "ansible-playbook -u centos -i '${self.public_ip},' --private-key keyfile.pem playbooks/springboot.yml"
  }
}

###### create nginx server
resource "aws_instance" "nginx" {
  ami = "ami-0083662ba17882949"
  instance_type = "t2.small"
  key_name = aws_key_pair.generated_key.key_name
  tags = {
    Name = "NGINX_SERVER"
  }
  vpc_security_group_ids = ["${aws_security_group.My_VPC_Security_Group-public.id}"]
  provisioner "remote-exec" {
    inline = ["sudo yum -y install python","sudo echo '${aws_instance.spring-boot.private_ip} springboot-server' |sudo tee -a /etc/hosts" ]
    connection {
      host = self.public_ip
      type        = "ssh"
      user        = "centos"
      private_key = tls_private_key.keyfile.private_key_pem
    }
  }
  provisioner "local-exec" {
    command = "python uibuild.py -i '${self.public_ip}'"
  }
  provisioner "local-exec" {
    command = "ansible-playbook -u centos -i '${self.public_ip},' --private-key keyfile.pem playbooks/nginx.yml"
  }
}


###print public ip
output "public_ip" {
  description = "nginx ip address http://publicip/"
  value       = aws_instance.nginx.*.public_ip
}