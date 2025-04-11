terraform {
  backend "s3" {
    bucket         = "cls-terraform-state-bucket"
    key            = "envs/dev/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "cls-terraform-lock-table"
    encrypt        = true
  }
}
