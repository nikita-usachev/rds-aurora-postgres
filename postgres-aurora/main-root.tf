# aurora-postgres

module "postgres-aurora" {
  source         = "../../modules/postgres-aurora"
  for_each       = { for index, key in var.rds_clusters : key.name => key if key.type == "aurora" }
  environment    = local.environment
  prefix         = var.prefix
  suffix         = "-${each.key}${local.suffix}"
  instance_class = lookup(each.value, "instance_class", null)
  # multi_az                = lookup(each.value, "multi_az", null)
  storage_type            = lookup(each.value, "storage_type", null)
  allocated_storage       = lookup(each.value, "allocated_storage", null)
  iops                    = lookup(each.value, "max_allocated_storage", null)
  database_name           = lookup(each.value, "database_name", null)
  database_username       = lookup(each.value, "master_username", null)
  database_password       = lookup(each.value, "master_password", null)
  engine_version          = lookup(each.value, "engine_version", null)
  parameters_additional   = lookup(each.value, "parameters", [])
  cloudwatch_logs_exports = lookup(each.value, "cloudwatch_logs_exports", null)
  ca_cert_identifier      = lookup(each.value, "ca_cert_identifier", null)
  security_groups = concat(
    [module.app-server.sg_id],
    lookup(each.value, "security_groups", [])
  )
  backup_retention                    = lookup(each.value, "backup_retention", null)
  deletion_protection                 = lookup(each.value, "deletion_protection", null)
  snapshot_identifier                 = lookup(each.value, "db_snapshot", null)
  iam_database_authentication_enabled = lookup(each.value, "iam_database_authentication_enabled", false)
  vpc_id                              = var.network_enabled ? module.network.vpc_id : var.vpc_id
  private_subnet_ids                  = var.network_enabled ? module.network.private_subnet_ids : null
  avail_zone                          = data.aws_availability_zones.selected.names[0]
  tags = {
    Application = "name"
    Component   = "aurora-postgres"
  }
  depends_on = [module.network]
}

# variables.tf

variable "rds_clusters" {
  type = list(object({
    name                                = string
    type                                = string
    instance_class                      = optional(string)
    engine_version                      = optional(string)
    storage_type                        = optional(string)
    allocated_storage                   = optional(number)
    iops                                = optional(number)
    dns_prefix                          = optional(string)
    db_name                             = optional(string)
    db_username                         = optional(string)
    db_password                         = optional(string)
    multi_az                            = optional(bool)
    parameters                          = optional(list(map(string)))
    cloudwatch_logs_exports             = optional(list(string))
    security_groups                     = optional(list(string))
    backup_retention                    = optional(number)
    deletion_protection                 = optional(bool)
    skip_final_snapshot                 = optional(bool)
    snapshot_identifier                 = optional(string)
    ca_cert_identifier                  = optional(string)
    iam_database_authentication_enabled = optional(bool)
  }))
  default = []
}

# tfvars

# aurora-postgres

rds_clusters = [
  {
    name                = "aurora-postgres"
    type                = "aurora"
    engine              = "aurora-postgresql"
    engine_version      = 14.7
    instance_class      = "db.r5.2xlarge"
    storage_type        = "gp3"
    allocated_storage   = 20
    iops                = 50
    database_name       = "name"
    master_password     = "password"
    master_username     = "postgres"
    parameters          = []
    security_groups     = []
    backup_retention    = 7
    skip_final_snapshot = false
    ca_cert_identifier  = "rds-ca-rsa2048-g1"
  }
]
