# 1. Web Tier Security Group (ALB): Allows HTTP from internet
resource "aws_security_group" "alb" {
  name        = "ha-alb-sg"
  description = "Allow inbound HTTP traffic from internet"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "alb-sg" }
}

# 2. App Tier Security Group (EC2 Instances): Allows traffic ONLY from the ALB
resource "aws_security_group" "app" {
  name        = "ha-app-sg"
  description = "Allow traffic from ALB only"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Allow traffic from ALB on port 80"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "app-sg" }
}

# 3. Database Tier Security Group (RDS): Allows traffic ONLY from the App tier
resource "aws_security_group" "db" {
  name        = "ha-db-sg"
  description = "Allow database traffic only from app servers"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Allow MySQL from App SG"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "db-sg" }
}