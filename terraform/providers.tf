provider "aws" {
  region = var.region
  # KHÔNG cần profile/assume-role – Jenkins đã inject ACCESS_KEY/SECRET
}

