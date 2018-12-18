#####################################################################
##
##      Created 12/4/18 by admin. for project1
##
#####################################################################

terraform {
  required_version = "> 0.8.0"
}

resource "aws_instance" "webapp" {
  ami           = "${lookup(var.AMIS, var.AWS_REGION)}"
  instance_type = "t1.micro"

  tags {
       Name = "WebApp"
    }

  # the VPC subnet
  subnet_id = "${aws_subnet.main-public-1.id}"

  # the security group
  vpc_security_group_ids = ["${aws_security_group.allow-ssh.id}"]

  # the public SSH key
  key_name = "${aws_key_pair.mykeypair.key_name}"

   #increase storage of root volume
  root_block_device{
    volume_size = 16
    volume_type = "gp2"
    delete_on_termination = true
  }
}

resource "aws_instance" "database" {
  ami           = "${lookup(var.AMIS, var.AWS_REGION)}"
  instance_type = "t1.micro"
  associate_public_ip_address = "false"
  vpc_security_group_ids = ["${aws_security_group.MySQLDB.id}"]
  # the VPC subnet
  subnet_id = "${aws_subnet.main-private-1.id}"

 
  tags {
        Name = "sql database"
  }
}

resource "aws_ebs_volume" "ebs-volume-1" {
    availability_zone = "${var.AWS_AVAILABILITY_ZONE}"
    size = 5
    type = "gp2" 
    tags {
        Name = "extra volume data"
    }
}

resource "aws_volume_attachment" "ebs-volume-1-attachment" {
  device_name = "/dev/xvdh"
  volume_id = "${aws_ebs_volume.ebs-volume-1.id}"
  instance_id = "${aws_instance.database.id}"
} 

resource "aws_security_group" "allow-ssh" {
  vpc_id = "${aws_vpc.main.id}"
  name = "allow-ssh"
  description = "security group that allows ssh and all egress traffic"
  egress {
      from_port = 0
      to_port = 0
      protocol = "-1"
      cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
      from_port = 22
      to_port = 22
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
        from_port = 80
        to_port = 80
        protocol = "TCP"
        cidr_blocks = ["0.0.0.0/0"]
    } 
tags {
    Name = "allow-ssh"
  }
}
resource "aws_security_group" "MySQLDB" {
    name = "MySQLDB"
     tags {
         Name = "MySQLDB"
    }
    description = "ONLY tcp CONNECTION INBOUND"
     vpc_id = "${aws_vpc.main.id}"
     ingress {
         from_port = 3306
         to_port = 3306
         protocol = "TCP"
         security_groups = ["${aws_security_group.allow-ssh.id}"]
    }
    ingress {
        from_port = "22"
        to_port = "22"
        protocol = "TCP"
        cidr_blocks = ["0.0.0.0/0"]
    }
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

# Internet VPC
resource "aws_vpc" "main" {
    cidr_block = "10.0.0.0/16"
    instance_tenancy = "default"
    enable_dns_support = "true"
    enable_dns_hostnames = "true"
    enable_classiclink = "false"
    tags {
        Name = "main"
    }
}


# Subnets
resource "aws_subnet" "main-public-1" {
    vpc_id = "${aws_vpc.main.id}"
    cidr_block = "10.0.1.0/24"
    map_public_ip_on_launch = "true"
    availability_zone = "${var.AWS_AVAILABILITY_ZONE}"

    tags {
        Name = "main-public-1"
    }
}
resource "aws_subnet" "main-private-1" {
    vpc_id = "${aws_vpc.main.id}"
    cidr_block = "10.0.6.0/24"
    map_public_ip_on_launch = "false"
    availability_zone = "${var.AWS_AVAILABILITY_ZONE}"

    tags {
        Name = "main-private-3"
    }
}

# Internet GW
resource "aws_internet_gateway" "main-gw" {
    vpc_id = "${aws_vpc.main.id}"

    tags {
        Name = "main"
    }
}

# route tables
resource "aws_route_table" "main-public" {
    vpc_id = "${aws_vpc.main.id}"
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = "${aws_internet_gateway.main-gw.id}"
    }

    tags {
        Name = "main-public-1"
    }
}

# route associations public
resource "aws_route_table_association" "main-public-1-a" {
    subnet_id = "${aws_subnet.main-public-1.id}"
    route_table_id = "${aws_route_table.main-public.id}"
}

resource "aws_key_pair" "mykeypair" {
  key_name = "mykeypair"
  public_key = "${file("${var.PATH_TO_PUBLIC_KEY}")}"
}
