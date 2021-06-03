terraform {
  required_version = "= 0.15.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "= 3.43.0"
    }
  }

}

resource "aws_ssm_parameter" "parameter_terraform" {
  name  = "/stuart-ellis/lab/tf/canary"
  value = "Terraform is active"
  type  = "String"
}
