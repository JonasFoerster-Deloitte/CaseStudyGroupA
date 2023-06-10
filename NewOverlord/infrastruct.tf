# Define provider and region
provider "aws" {
  region = "eu-central-1"
}

# Create VPC
resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"  
}

# Create Subnets
resource "aws_subnet" "subnet_a" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.0.0/24"  
  availability_zone       = "eu-central-1a"
}

resource "aws_subnet" "subnet_b" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.1.0/24"  
  availability_zone       = "eu-central-1b"
}

# Create Security Group
resource "aws_security_group" "my_security_group" {
  vpc_id = aws_vpc.my_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
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
}

# Create DB Subnet Group
resource "aws_db_subnet_group" "my_subnet_group" {
  name        = "my-subnet-group"
  subnet_ids  = [aws_subnet.subnet_a.id, aws_subnet.subnet_b.id]
}

# Create RDS Database with Encryption
resource "aws_db_instance" "my_rds" {
  identifier               = "my-wordpress-db"
  allocated_storage        = 20
  storage_type             = "gp2"
  engine                   = "mysql"
  engine_version           = "5.7"
  instance_class           = "db.m5.large"
  username                 = "admin"
  password                 = "password123"  
  db_subnet_group_name     = aws_db_subnet_group.my_subnet_group.name
  storage_encrypted        = true  
  kms_key_id               = aws_kms_key.my_kms_key.arn 
}

# Create ECS Cluster
resource "aws_ecs_cluster" "my_ecs_cluster" {
  name = "my-ecs-cluster"
}

# Create Task Definition
resource "aws_ecs_task_definition" "my_task_definition" {
  family                   = "my-task"
  container_definitions    = <<DEFINITION
[
  {
    "name": "wordpress",
    "image": "wordpress:latest",
    "portMappings": [
      {
        "containerPort": 80,
        "hostPort": 80,
        "protocol": "tcp"
      }
    ],
    "environment": [
      {
        "name": "WORDPRESS_DB_HOST",
        "value": "${aws_db_instance.my_rds.address}"
      },
      {
        "name": "WORDPRESS_DB_USER",
        "value": "${aws_db_instance.my_rds.username}"
      },
      {
        "name": "WORDPRESS_DB_PASSWORD",
        "value": "${aws_db_instance.my_rds.password}"
      },
      {
        "name": "WORDPRESS_DB_NAME",
        "value": "wordpress"
      }
    ],
    "memory": 512,
    "essential": true
  },
  {
    "name": "phpmyadmin",
    "image": "phpmyadmin/phpmyadmin:latest",
    "portMappings": [
      {
        "containerPort": 80,
        "hostPort": 8080,
        "protocol": "tcp"
      }
    ],
    "environment": [
      {
        "name": "PMA_HOST",
        "value": "${aws_db_instance.my_rds.address}"
      },
      {
        "name": "PMA_USER",
        "value": "${aws_db_instance.my_rds.username}"
      },
      {
        "name": "PMA_PASSWORD",
        "value": "${aws_db_instance.my_rds.password}"
      }
    ],
    "memory": 512,
    "essential": true
  }
]
DEFINITION

  requires_compatibilities = ["EC2"]
}


# Create ECS Service
resource "aws_ecs_service" "my_ecs_service" {
  name            = "my-ecs-service"
  cluster         = aws_ecs_cluster.my_ecs_cluster.id
  task_definition = aws_ecs_task_definition.my_task_definition.arn
  desired_count   = 1
  launch_type     = "EC2"

  deployment_controller {
    type = "ECS"
  }

}

# Create KMS Key for RDS Encryption
resource "aws_kms_key" "my_kms_key" {
  description             = "RDS encryption key"
  deletion_window_in_days = 30 
  tags = {
    Name = "my-kms-key"
  }
}

# Attach Key Policy to KMS Key (optional: modify as needed)
resource "aws_kms_key_policy" "my_kms_key_policy" {
  key_id = aws_kms_key.my_kms_key.key_id
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Sid       = "Enable IAM User Permissions"
        Effect    = "Allow"
        Principal = {
          AWS = "arn:aws:iam::238517445739:user/za-pract" 
        }
        Action    = "kms:*"
        Resource  = "*"
      },
    ]
  })
}