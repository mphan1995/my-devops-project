AWS_REGION ?= ap-southeast-1

.PHONY: tf-init tf-plan tf-apply tf-destroy kubeconfig ansible-bootstrap helm-deploy

tf-init:
	cd terraform && terraform init -input=false

tf-plan:
	cd terraform && terraform plan -input=false \
	  -var="aws_account_id=507737351904" -var="region=$(AWS_REGION)"

tf-apply:
	cd terraform && terraform apply -input=false -auto-approve \
	  -var="aws_account_id=507737351904" -var="region=$(AWS_REGION)"

kubeconfig:
	./scripts/get_kubeconfig.sh

ansible-bootstrap:
	ansible-galaxy install -r ansible/requirements.yml
	ansible-playbook -i ansible/inventory.ini ansible/playbooks/cluster_bootstrap.yml

helm-deploy:
	ECR=$$(terraform -chdir=terraform output -raw ecr_uri); \
	./scripts/render_values.sh helm/myapp/values.yaml image.repository $$ECR/myapp; \
	helm upgrade --install myapp helm/myapp -n myapp --create-namespace

.tfclean:
	rm -rf terraform/.terraform terraform/.terraform.lock.hcl terraform/tfplan