terraform {
  backend "s3" {
    bucket = "file-sharing-tfstate"
    key    = "terraform/backend"
    region = "us-east-1"

  }
}