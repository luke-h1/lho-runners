output "runners" {
  value = {
    lambda_syncer_name = module.runners.binaries_syncer.lambda.function_name
  }
}

output "webook_secret" {
  value     = random_id.random.hex
  sensitive = false
}

output "webhook_endpoint" {
  value = module.runners.webhook.endpoint
}

output "packer_config" {
  description = "Configuration values for Packer AMI builds"
  value = {
    region                      = var.aws_region
    subnet_id                   = module.base.vpc.public_subnets[0]
    security_group_id           = module.base.vpc.default_security_group_id
    associate_public_ip_address = true
  }
}
