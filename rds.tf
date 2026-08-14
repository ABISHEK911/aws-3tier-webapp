resource "aws_db_subnet_group" "main" {
 name       = "tier-webapp-db-subnet-group"
  subnet_ids = aws_subnet.private_db[*].id

  tags = {
    name       = "tier-webapp-db-subnet-group"
  }
}

resource "aws_db_instance" "main" {
  identifier     = "tier-webapp-db"
  engine         = "mysql"
  engine_version = "8.0"
  instance_class = "db.t3.micro"

  allocated_storage = 20
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = "appdb"
  username = "admin"
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.db.id]

  multi_az            = false
  publicly_accessible = false

  backup_retention_period = 1
  skip_final_snapshot     = true

  tags = {
    name       = "tier-webapp-db-subnet-group"
  }
}