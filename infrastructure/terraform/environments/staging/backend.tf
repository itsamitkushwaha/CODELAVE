terraform {
  backend "s3" {
    bucket         = "codelave-tf-state-backend-4815162342"
    key            = "staging/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
  }
}
