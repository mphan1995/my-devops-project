provider "aws" {
  region = var.region
}

# Kubernetes provider sẽ được cấu hình sau khi EKS tạo xong (dùng data aws_eks_cluster)