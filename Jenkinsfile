pipeline {
  agent any

  environment {
    AWS_DEFAULT_REGION = 'ap-southeast-1'
    KUBECONFIG = "${WORKSPACE}/.kube/config"
  }

  options {
    timestamps()
    ansiColor('xterm')
  }

  parameters {
    booleanParam(name: 'DESTROY', defaultValue: false, description: 'Destroy all resources first')
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Setup AWS & Tools') {
      steps {
        withCredentials([
          string(credentialsId: 'aws-region', variable: 'REGION_OPT'),
          [$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds']
        ]) {
          sh '''
            set -eu
            export AWS_DEFAULT_REGION="${REGION_OPT:-$AWS_DEFAULT_REGION}"

            # Normalize line endings for helper scripts
            sed -i 's/\r$//' scripts/*.sh || true

            echo "Using AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION"
            aws --version || true
            terraform -version || true
            kubectl version --client=true || true
            helm version || true
            ansible --version || true

            echo "== AWS identity =="
            aws sts get-caller-identity
          '''
        }
      }
    }

    stage('Terraform Init/Plan/Apply') {
      when {
        expression { !params.DESTROY }
      }
      steps {
        withCredentials([
          string(credentialsId: 'aws-region', variable: 'REGION_OPT'),
          [$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds']
        ]) {
          sh '''
            set -eu
            export AWS_DEFAULT_REGION="${REGION_OPT:-$AWS_DEFAULT_REGION}"
            cd terraform

            terraform init -input=false
            terraform fmt -recursive
            terraform fmt -check || true
            terraform validate

            terraform plan -input=false -out=tfplan \
              -var="aws_account_id=507737351904" \
              -var="region=${AWS_DEFAULT_REGION}"

            terraform apply -input=false -auto-approve tfplan
          '''
        }
      }
    }

    stage('Terraform Destroy (if requested)') {
      when {
        expression { params.DESTROY }
      }
      steps {
        withCredentials([
          string(credentialsId: 'aws-region', variable: 'REGION_OPT'),
          [$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds']
        ]) {
          sh '''
            set -eu
            export AWS_DEFAULT_REGION="${REGION_OPT:-$AWS_DEFAULT_REGION}"
            cd terraform

            terraform init -input=false
            terraform destroy -auto-approve \
              -var="aws_account_id=507737351904" \
              -var="region=${AWS_DEFAULT_REGION}"
          '''
        }
      }
    }

    stage('Configure kubeconfig') {
      when {
        expression { !params.DESTROY }
      }
      steps {
        withCredentials([
          string(credentialsId: 'aws-region', variable: 'REGION_OPT'),
          [$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds']
        ]) {
          sh '''
            set -eu
            export AWS_DEFAULT_REGION="${REGION_OPT:-$AWS_DEFAULT_REGION}"

            mkdir -p "$(dirname "$KUBECONFIG")"

            # In case scripts are CRLF
            sed -i 's/\r$//' scripts/*.sh || true

            CLUSTER="$(terraform -chdir=terraform output -raw eks_cluster_name)"
            aws eks update-kubeconfig --name "$CLUSTER" --region "$AWS_DEFAULT_REGION" --kubeconfig "$KUBECONFIG"

            kubectl get nodes
          '''
        }
      }
    }

    stage('Ansible Bootstrap') {
      when {
        expression { !params.DESTROY }
      }
      steps {
        withCredentials([
          [$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds']
        ]) {
          sh '''
            set -eu
            # Ensure KUBECONFIG is present for k8s modules if used
            [ -f "$KUBECONFIG" ] && kubectl config current-context || true

            ansible-galaxy collection install kubernetes.core community.kubernetes --force
            ansible-galaxy install -r ansible/requirements.yml || true
            ansible-playbook -i ansible/inventory.ini ansible/playbooks/cluster_bootstrap.yml
          '''
        }
      }
    }

    stage('Helm Deploy App') {
      when {
        expression { !params.DESTROY }
      }
      steps {
        withCredentials([
          [$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds']
        ]) {
          sh '''
            set -eu
            # Use POSIX '.' instead of Bash 'source' for portability
            . ./scripts/ecr_login.sh

            ECR_URI="$(terraform -chdir=terraform output -raw ecr_uri)"
            ./scripts/render_values.sh helm/myapp/values.yaml image.repository "$ECR_URI/myapp"

            helm upgrade --install myapp helm/myapp -n myapp --create-namespace \
              --set image.tag=v0.1.0

            kubectl -n myapp rollout status deploy/myapp --timeout=120s || true
          '''
        }
      }
    }
  }

  post {
    always {
      sh '''
        set +e
        # Re-assert kubeconfig for post steps
        export KUBECONFIG="${KUBECONFIG:-$WORKSPACE/.kube/config}"
        kubectl -n myapp get pods || true
      '''
      archiveArtifacts artifacts: 'terraform/*.tfstate*', fingerprint: true, onlyIfSuccessful: false
    }
  }
}
