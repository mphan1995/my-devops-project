# My DevOps Project

Infra: Terraform → VPC, EKS, ECR.\
Ops: Ansible → bootstrap cluster, tạo namespace/secrets.\
App: Helm → deploy myapp từ ECR.

## Yêu cầu môi trường (máy Jenkins agent)
- awscli v2
- terraform >= 1.6
- kubectl >= 1.28
- helm >= 3.12
- ansible >= 2.16, python3-boto3, botocore
- docker (để build/push image lên ECR nếu cần)

## Quickstart (local)
```bash
make tf-init
make tf-apply # tạo VPC/EKS/ECR
./scripts/get_kubeconfig.sh
ansible-galaxy install -r ansible/requirements.yml
ansible-playbook -i ansible/inventory.ini ansible/playbooks/cluster_bootstrap.yml
./scripts/ecr_login.sh
helm upgrade --install myapp helm/myapp -n myapp --create-namespace \
  --set image.repository="$ECR_URI/myapp" --set image.tag="v0.1.0"