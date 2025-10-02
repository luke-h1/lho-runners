resource "random_id" "random" {
  byte_length = 20
}

module "base" {
  source     = "./modules/base"
  prefix     = var.env
  aws_region = var.aws_region
}

data "aws_caller_identity" "current" {}

resource "aws_kms_key" "github" {
  is_enabled = true
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow CloudWatch Logs"
        Effect = "Allow"
        Principal = {
          Service = "logs.${var.aws_region}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_kms_alias" "github" {
  name          = "alias/github/action-runners"
  target_key_id = aws_kms_key.github.key_id
}

module "runners" {
  source     = "git::https://github.com/github-aws-runners/terraform-aws-github-runner?ref=v6.7.9"
  prefix     = "lho-${var.env}-github-runners"
  aws_region = var.aws_region

  github_app = {
    id             = var.github_app_id
    key_base64     = var.github_app_private_key
    webhook_secret = var.github_app_webhook_secret
  }

  ami_filter = {
    name  = ["*ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
    state = ["available"]
  }

  ami_housekeeper_lambda_zip        = "../lambdas/ami-housekeeper.zip"
  runner_binaries_syncer_lambda_zip = "../lambdas/runner-binaries-syncer.zip"
  runners_lambda_zip                = "../lambdas/runners.zip"
  webhook_lambda_zip                = "../lambdas/webhook.zip"

  runner_os                     = "linux"
  enable_organization_runners   = false
  runner_disable_default_labels = false

  runners_scale_up_lambda_timeout   = 60
  runners_scale_down_lambda_timeout = 60

  eventbridge = {
    enable        = true
    accept_events = []
  }

  enable_ssm_on_runners = true

  instance_types = ["t3.small"]

  enable_ami_housekeeper        = true
  enable_runner_binaries_syncer = true
  vpc_id                        = module.base.vpc.vpc_id
  subnet_ids                    = module.base.vpc.private_subnets
  logging_retention_in_days     = 7
  runners_maximum_count         = 5

  kms_key_arn = aws_kms_key.github.arn

  instance_target_capacity_type = "on-demand"
  logging_kms_key_id            = aws_kms_key.github.arn

  scale_down_schedule_expression        = "cron(* * * * ? *)"
  enable_user_data_debug_logging_runner = true

  queue_encryption = {
    kms_data_key_reuse_period_seconds = 60
    kms_master_key_id                 = aws_kms_key.github.arn
    sqs_managed_sse_enabled           = null
  }

  pool_config = [{
    size                         = 2
    schedule_expression          = "cron(* * * * ? *)" # every minute
    schedule_expression_timezone = "Europe/London"
  }]

  idle_config = [{
    cron      = "* * 9-19 * * 1-5" # 9AM to 7PM keep 2 runners idle to pick up jobs
    timeZone  = "Europe/London"
    idleCount = 2
    # Defaults to 'oldest_first'
    evictionStrategy = "oldest_first"
  }]

  delay_webhook_event = 1

  runner_name_prefix = "lho-${var.env}-github-runners"
  providers = {
    aws = aws.terraform_role
  }

  tracing_config = {
    mode                  = "Active"
    capture_error         = true
    capture_http_requests = true
  }
  job_retry = {
    enable           = true
    max_attempts     = 5
    delay_in_seconds = 15
  }
}
