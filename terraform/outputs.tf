output "eks_cluster_name" { value = module.eks.cluster_name }
output "ecr_uri" { value = aws_ecr_repository.myapp.repository_url }