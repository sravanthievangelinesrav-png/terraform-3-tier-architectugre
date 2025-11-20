terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.73.0"
    }
  }
}

# Configure AWS Provider
provider "aws" {
  region = "us-east-1"
}

#---------------------------------------------
# VPC
#---------------------------------------------
resource "aws_vpc" "my-vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "my-VPC"
  }
}

#---------------------------------------------
# PUBLIC SUBNETS (WEB)
#---------------------------------------------
resource "aws_subnet" "web-subnet-1" {
  vpc_id                  = aws_vpc.my-vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "Web-1a"
  }
}

resource "aws_subnet" "web-subnet-2" {
  vpc_id                  = aws_vpc.my-vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "Web-lb"
  }
}

#---------------------------------------------
# PRIVATE SUBNETS (APPLICATION)
#---------------------------------------------
resource "aws_subnet" "application-subnet-1" {
  vpc_id                  = aws_vpc.my-vpc.id
  cidr_block              = "10.0.11.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "Application-1a"
  }
}

resource "aws_subnet" "application-subnet-2" {
  vpc_id                  = aws_vpc.my-vpc.id
  cidr_block              = "10.0.12.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "Application-1b"
  }
}

#---------------------------------------------
# PRIVATE SUBNETS (DATABASE)
#---------------------------------------------
resource "aws_subnet" "database-subnet-1" {
  vpc_id            = aws_vpc.my-vpc.id
  cidr_block        = "10.0.21.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "Database-1a"
  }
}

resource "aws_subnet" "database-subnet-2" {
  vpc_id            = aws_vpc.my-vpc.id
  cidr_block        = "10.0.22.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "Database-1b"
  }
}

#---------------------------------------------
# INTERNET GATEWAY
#---------------------------------------------
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.my-vpc.id

  tags = {
    Name = "SWIGGY-IGW"
  }
}

#---------------------------------------------
# ROUTE TABLE (WEB)
#---------------------------------------------
resource "aws_route_table" "web-rt" {
  vpc_id = aws_vpc.my-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "WebRT"
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.web-subnet-1.id
  route_table_id = aws_route_table.web-rt.id
}

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.web-subnet-2.id
  route_table_id = aws_route_table.web-rt.id
}

#---------------------------------------------
# SECURITY GROUPS
#---------------------------------------------
# Web SG
resource "aws_security_group" "webserver-sg" {
  name        = "webserver-sg"
  description = "Allow HTTP inbound traffic"
  vpc_id      = aws_vpc.my-vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Web-SG"
  }
}

# App SG
resource "aws_security_group" "appserver-sg" {
  name        = "appserver-sg"
  description = "Allow inbound traffic to app layer"
  vpc_id      = aws_vpc.my-vpc.id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "App-SG"
  }
}

# Database SG
resource "aws_security_group" "database-sg" {
  name        = "database-sg"
  description = "Allow app layer to reach DB"
  vpc_id      = aws_vpc.my-vpc.id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Database-SG"
  }
}

#---------------------------------------------
# EC2 INSTANCES (WEB)
#---------------------------------------------
resource "aws_instance" "webserver1" {
  ami                    = "ami-0d5eff06f840b45e9"
  instance_type          = "t2.micro"
  availability_zone      = "us-east-1a"
  key_name               = "terra"
  vpc_security_group_ids = [aws_security_group.webserver-sg.id]
  subnet_id              = aws_subnet.web-subnet-1.id
  user_data              = file("apache.sh")

  tags = {
    Name = "Web Server-1"
  }
}

resource "aws_instance" "webserver2" {
  ami                    = "ami-0d5eff06f840b45e9"
  instance_type          = "t2.micro"
  availability_zone      = "us-east-1b"
  key_name               = "terra"
  vpc_security_group_ids = [aws_security_group.webserver-sg.id]
  subnet_id              = aws_subnet.web-subnet-2.id
  user_data              = file("apache.sh")

  tags = {
    Name = "Web Server-2"
  }
}

#---------------------------------------------
# EC2 INSTANCES (APP LAYER)
#---------------------------------------------
resource "aws_instance" "appserver1" {
  ami                    = "ami-0d5eff06f840b45e9"
  instance_type          = "t2.micro"
  availability_zone      = "us-east-1a"
  key_name               = "terra"
  vpc_security_group_ids = [aws_security_group.appserver-sg.id]
  subnet_id              = aws_subnet.application-subnet-1.id

  tags = {
    Name = "App Server-1"
  }
}

resource "aws_instance" "appserver2" {
  ami                    = "ami-0d5eff06f840b45e9"
  instance_type          = "t2.micro"
  availability_zone      = "us-east-1b"
  key_name               = "terra"
  vpc_security_group_ids = [aws_security_group.appserver-sg.id]
  subnet_id              = aws_subnet.application-subnet-2.id

  tags = {
    Name = "App Server-2"
  }
}

#---------------------------------------------
# RDS SUBNET GROUP
#---------------------------------------------
resource "aws_db_subnet_group" "default" {
  name       = "main"
  subnet_ids = [
    aws_subnet.database-subnet-1.id,
    aws_subnet.database-subnet-2.id
  ]

  tags = {
    Name = "My DB subnet group"
  }
}

#---------------------------------------------
# RDS INSTANCE (MYSQL LATEST)
#---------------------------------------------
resource "aws_db_instance" "default" {
  allocated_storage      = 10
  db_name                = "mydb"
  engine                 = "mysql"
  engine_version         = "8.0.39"   # Latest version
  instance_class         = "db.t3.micro"
  username               = "admin"
  password               = "Raham#123568i"
  db_subnet_group_name   = aws_db_subnet_group.default.name
  vpc_security_group_ids = [aws_security_group.database-sg.id]
  skip_final_snapshot    = true
}

#---------------------------------------------
# ALB
#---------------------------------------------
resource "aws_lb" "external-elb" {
  name               = "External-LB"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.webserver-sg.id]
  subnets            = [
    aws_subnet.web-subnet-1.id,
    aws_subnet.web-subnet-2.id
  ]
}

resource "aws_lb_target_group" "external-elb" {
  name     = "ALB-TG"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.my-vpc.id
}

resource "aws_lb_target_group_attachment" "external-elb1" {
  target_group_arn = aws_lb_target_group.external-elb.arn
  target_id        = aws_instance.webserver1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "external-elb2" {
  target_group_arn = aws_lb_target_group.external-elb.arn
  target_id        = aws_instance.webserver2.id
  port             = 80
}

resource "aws_lb_listener" "external-elb" {
  load_balancer_arn = aws_lb.external-elb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.external-elb.arn
  }
}

output "lb_dns_name" {
  value = aws_lb.external-elb.dns_name
}

#---------------------------------------------
# S3 BUCKET
#---------------------------------------------
resource "aws_s3_bucket" "example" {
  bucket = "sravanthi-bucket-123-dev"

  tags = {
    Name        = "sravanthi-bucket-123-dev"
    Environment = "Dev"
  }
}

#---------------------------------------------
# IAM USERS
#---------------------------------------------
variable "iam_users" {
  type    = set(string)
  default = ["userone", "usertwo", "userthree", "userfour"]
}

resource "aws_iam_user" "one" {
  for_each = var.iam_users
  name     = each.value
}

resource "aws_iam_group" "two" {
  name = "sravanthievangelinesrav-png"
}
