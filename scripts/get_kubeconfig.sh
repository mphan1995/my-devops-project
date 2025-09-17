#!/usr/bin/env bash
set -euo pipefail
REGION=${AWS_DEFAULT_REGION:-ap-southeast-1}
CLUSTER=$(terraform -chdir=terraform output -raw eks_cluster_name)
aws eks update-kubeconfig --name "$CLUSTER" --region "$REGION"