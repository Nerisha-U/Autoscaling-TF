provider "aws" {
  region = "us-east-1"
}

data "aws_ami" "ami" {
    most_recent = true

    filter {
        name = "virtualization-type"
        values = ["hvm"]
    }

    filter {
        name = "name"
        values = ["amzn2-ami-hvm*"]
    }

    owners = ["137112412989"]
}

//creating launch configuration
resource "aws_launch_configuration" "Neri-launch-config" {
  image_id        = data.aws_ami.ami.id
  instance_type   = "t2.micro"
  security_groups = ["aws_security_group.Neri-asg-sg.id"]
  user_data = <<-EOF
              #!/bin/bash
              yum -y install httpd
              echo "Hello, this is coming from Terraform" > /var/www/html/index.html
              service httpd start
              chkconfig httpd on
              EOF

  lifecycle {
    create_before_destroy = true
  }
}

variable "vpc_id" {}


variable "target_group_arn" {}

variable "subnet1" {}
variable "subnet2" {}


//defining autoscaling group 
resource "aws_autoscaling_group" "tf-asg" {
  launch_configuration = "aws_launch_configuration.Neri-launch-config.name"
  vpc_zone_identifier  = ["var.subnet1","var.subnet2 ]
  target_group_arns    = ["var.target_group_arn"]
  health_check_type    = "ELB"

  min_size = 2
  max_size = 10

  tag {
    key                 = "Name"
    value               = "Neri-asg"
    propagate_at_launch = true //this will copy tag to EC2 instances created as part of ASG
  }
}

resource "aws_security_group" "Neri-asg-sg" {
  name   = "Neri-asg-sg"
  vpc_id = "{var.vpc_id}"
}

resource "aws_security_group_rule" "inbound_ssh" {
  from_port         = 22
  protocol          = "tcp"
  security_group_id = "${aws_security_group.Neri-asg-sg.id}"
  to_port           = 22
  type              = "ingress"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "inbound_http" {
  from_port         = 80
  protocol          = "tcp"
  security_group_id = "${aws_security_group.Neri-asg-sg.id}"
  to_port           = 80
  type              = "ingress"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "outbound_all" {
  from_port         = 0
  protocol          = "-1"
  security_group_id = "${aws_security_group.Neri-asg-sg.id}"
  to_port           = 0
  type              = "egress"
  cidr_blocks       = ["0.0.0.0/0"]
}