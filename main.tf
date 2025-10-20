# VPC creation
resource "aws_vpc" "myvpc" {
  cidr_block = var.cidr
}

#subnet1 @ 2 creation
resource "aws_subnet" "sub1" {
  vpc_id                  = aws_vpc.myvpc.id
  cidr_block              = var.subcidr
  availability_zone       = "eu-north-1a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "sub2" {
  vpc_id                  = aws_vpc.myvpc.id
  cidr_block              = var.subcidr1
  availability_zone       = "eu-north-1b"
  map_public_ip_on_launch = true
}

#internet gateway to access public subnets
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.myvpc.id
}

#Route table[defines how traffic floe inside the subnets] have to attach to public subnet
resource "aws_route_table" "art" {
  vpc_id = aws_vpc.myvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

#associate route table eith subnet 
resource "aws_route_table_association" "rta1" {
  route_table_id = aws_route_table.art.id
  subnet_id      = aws_subnet.sub1.id
}

resource "aws_route_table_association" "rta2" {
  route_table_id = aws_route_table.art.id
  subnet_id      = aws_subnet.sub2.id
}

#security group for load balancer, EC2 [we should use new SG for LB]
resource "aws_security_group" "web-sg" {
  name   = "web"
  vpc_id = aws_vpc.myvpc.id

  ingress {
    description = "HTTP from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "web-sg"
  }
}

#S3 bucket
resource "aws_s3_bucket" "eample" {
  bucket = "pandugulaterraformproject"
}

#EC2 instances creation
resource "aws_instance" "webserver1" {
  ami                    = "ami-0a716d3f3b16d290c"
  instance_type          = "t3.micro"
  vpc_security_group_ids = [aws_security_group.web-sg.id]
  subnet_id              = aws_subnet.sub1.id
  user_data_base64       = base64encode(file("userdata.sh"))
}

resource "aws_instance" "webserver2" {
  ami                    = "ami-0a716d3f3b16d290c"
  instance_type          = "t3.micro"
  vpc_security_group_ids = [aws_security_group.web-sg.id]
  subnet_id              = aws_subnet.sub2.id
  user_data_base64       = base64encode(file("userdata.sh"))
}

#load balancer b/w EC2
resource "aws_lb" "mylb" {
    name = "mylb"
    internal = false  
    load_balancer_type= "application"
    security_groups = [aws_security_group.web-sg.id]
    subnets = [aws_subnet.sub1.id, aws_subnet.sub2.id]

    tags = {
        name= "web"
    }
}

#target group
resource "aws_lb_target_group" "ltg" {
    name= "myTG"
    port= 80
    protocol = "HTTP"
    vpc_id= aws_vpc.myvpc.id

    health_check {
      path ="/"
      port =  "traffic-port"
    }
}

#target group attachment to instances
resource "aws_lb_target_group_attachment" "attach1" {
   target_group_arn = aws_lb_target_group.ltg.arn
   target_id = aws_instance.webserver1.id
}


resource "aws_lb_target_group_attachment" "attach2" {
   target_group_arn = aws_lb_target_group.ltg.arn
   target_id = aws_instance.webserver2.id
}

#listener to attach load balancer
resource "aws_lb_listener" "listener" {
    load_balancer_arn = aws_lb.mylb.arn
    port = 80
    protocol = "HTTP"

    default_action {
      type = "forward"
      target_group_arn = aws_lb_target_group.ltg.arn
    }
}

#output similar to outputs.tf

output "loadbalancers" {
  value = aws_lb.mylb.dns_name
}