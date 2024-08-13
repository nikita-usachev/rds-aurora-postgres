terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.13.1"
    }
  }
  required_version = ">= 1.3.3"
}

# data

data "aws_vpc" "selected" {
  id      = var.vpc_id
  default = var.vpc_id != null ? false : true
}

# security group

resource "aws_security_group" "database" {
  name        = "${local.common_tags.Name}-sg"
  description = var.database_security_group_description
  vpc_id      = data.aws_vpc.selected.id

  tags = merge(local.tags, { Name = "${local.common_tags.Name}-sg" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "database_allow_inbound" {
  count                    = length(var.security_groups) > 0 ? length(var.security_groups) : 0
  description              = "Inbound traffic from instances"
  type                     = "ingress"
  from_port                = var.database_port
  to_port                  = var.database_port
  protocol                 = "tcp"
  source_security_group_id = var.security_groups[count.index]
  security_group_id        = aws_security_group.database.id
}

resource "aws_security_group_rule" "database_outbound" {
  description       = "Outbound traffic anywhere"
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.database.id
}

# database

resource "aws_rds_cluster_parameter_group" "database" {
  name   = local.common_tags.Name
  family = "aurora-postgresql14" # "${var.database_engine}${split(".", var.engine_version)[0]}"
  tags   = merge(local.tags, { Name = local.common_tags.Name })

  dynamic "parameter" {
    for_each = local.parameters
    content {
      name         = parameter.value.name
      value        = parameter.value.value
      apply_method = lookup(parameter.value, "apply_method", null)
    }
  }
}

resource "aws_db_subnet_group" "database" {
  name       = local.common_tags.Name
  subnet_ids = var.private_subnet_ids
  tags       = merge(local.tags, { Name = local.common_tags.Name })
}

resource "aws_rds_cluster" "database" {
  cluster_identifier                  = local.common_tags.Name
  database_name                       = var.database_name
  master_username                     = var.database_username
  master_password                     = var.database_password
  port                                = var.database_port
  engine                              = var.database_engine
  engine_version                      = var.engine_version
  db_cluster_instance_class           = var.instance_class
  storage_encrypted                   = var.storage_encrypted
  storage_type                        = var.storage_type
  allocated_storage                   = var.allocated_storage
  iops                                = var.iops
  availability_zones                  = ["us-east-2a"] # [var.avail_zone]
  # multi_az                            = false
  vpc_security_group_ids              = [aws_security_group.database.id]
  db_subnet_group_name                = aws_db_subnet_group.database.name
  db_cluster_parameter_group_name     = aws_rds_cluster_parameter_group.database.name
  tags                                = merge(local.tags, { Name = local.common_tags.Name })
  skip_final_snapshot                 = var.skip_final_snapshot
  final_snapshot_identifier           = "${local.common_tags.Name}-final-snapshot"
  backup_retention_period             = var.backup_retention
  snapshot_identifier                 = var.snapshot_identifier
  enabled_cloudwatch_logs_exports     = var.cloudwatch_logs_exports
  apply_immediately                   = var.apply_immediately
  deletion_protection                 = var.deletion_protection
  iam_database_authentication_enabled = var.iam_database_authentication_enabled
  lifecycle {
    ignore_changes = [
      snapshot_identifier,
      engine_version,
      availability_zones
    ]
  }
}

resource "aws_rds_cluster_instance" "database" {
  identifier              = local.common_tags.Name
  count                   = 1
  cluster_identifier      = aws_rds_cluster.database.id
  instance_class          = var.instance_class
  engine                  = aws_rds_cluster.database.engine
  engine_version          = aws_rds_cluster.database.engine_version
  db_subnet_group_name    = aws_db_subnet_group.database.name
  db_parameter_group_name = aws_rds_cluster_parameter_group.database.name
  ca_cert_identifier      = var.ca_cert_identifier
  availability_zone       = var.avail_zone
  # multi_az                            = false
  auto_minor_version_upgrade = "true"
  tags                       = merge(local.tags, { Name = local.common_tags.Name })
  publicly_accessible        = false
}
