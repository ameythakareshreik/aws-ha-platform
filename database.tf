# 1. Database Subnet Group across Private DB Subnets
resource "aws_db_subnet_group" "main" {
  name       = "ha-db-subnet-group"
  subnet_ids = aws_subnet.private_db[*].id

  tags = { Name = "ha-db-subnet-group" }
}

# 2. Random Password Generation for DB Security
resource "random_password" "db_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# 3. Store DB Credentials in AWS Secrets Manager
resource "aws_secretsmanager_secret" "db_credentials" {
  name                    = "ha-platform-db-credentials"
  recovery_window_in_days = 0 # Ensures quick cleanup if destroyed
}

resource "aws_secretsmanager_secret_version" "db_credentials_val" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = "adminuser"
    password = random_password.db_password.result
    engine   = "mysql"
    port     = 3306
  })
}

# 4. Multi-AZ RDS Instance (Primary + Standby in 2nd AZ)
resource "aws_db_instance" "main" {
  identifier             = "ha-platform-db"
  allocated_storage      = 20
  max_allocated_storage  = 50
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro" # Free-tier eligible
  db_name                = "appdb"
  username               = "adminuser"
  password               = random_password.db_password.result
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.db.id]
  
  # Crucial HA Setting
  multi_az               = true
  
  # Backup & Maintenance Settings
  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  skip_final_snapshot     = true

  tags = { Name = "ha-rds-database" }
}