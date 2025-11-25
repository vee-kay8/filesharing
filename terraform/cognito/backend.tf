terraform {
  backend "s3" {
    bucket = "file-sharing-tfstate"
    key    = "terraform/cognitobackend"
    region = "us-east-1"

  }
}