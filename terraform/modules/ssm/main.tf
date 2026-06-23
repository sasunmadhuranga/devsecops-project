variable "project" {}
variable "environment" {}
variable "jwt_secret" { sensitive = true }

resource "aws_ssm_parameter" "jwt_secret" {
  name        = "/${var.project}/${var.environment}/JWT_SECRET"
  description = "JWT signing secret for the ${var.environment} environment"
  type        = "SecureString"
  value       = var.jwt_secret
  tier        = "Standard"

  tags = { Name = "${var.project}-${var.environment}-jwt-secret" }
}

output "jwt_secret_arn" { value = aws_ssm_parameter.jwt_secret.arn }
