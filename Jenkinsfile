pipeline {
  agent any

  environment {
    AWS_DEFAULT_REGION = 'ap-southeast-1'
  }

  options {
    timestamps()
    ansiColor('xterm')
  }

  stages {
    stage('Checkout') {
      steps { checkout scm }
    }

    stage('Setup AWS & Tools') {
      steps {
        withCredentials([string(credentialsId: 'aws-region', variable: 'REGION_OPT')]) {
          withCredentials([[
            $class: 'AmazonWebServicesCredentialsBinding',
            credentialsId: 'aws-creds'
          ]]) {
            sh '''
              export AWS_DEFAULT_REGION="${REGION_OPT:-$AWS_DEFAULT_REGION}"
              echo "Using AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION"

              aws --version || true
              terraform -version || true
              kubectl version --client || true
              helm version || true
              ansible --version || true

              aws sts get-caller-identity
            '''
          }
        }
      }
    }

    stage('Terraform Init/Plan/Apply') {
      steps {
        // Bind lại AWS creds + (optional) region secret
        withCredentials([string(credentialsId: 'aws-region', variable: 'REGION_OPT')]) {
          withCredentials([[
            $class: 'AmazonWebServicesCredentialsBinding',
            credentialsId: 'aws-creds'
          ]]) {
            sh '''
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
    }

    stage('Configure kubeconfig') {
      environment {
        KUBECONFIG = "${env.WORKSPACE}/kubeconfig"   // luôn dùng file trong workspace
        CLUSTER_NAME = "my-devops-project-eks"       // hoặc lấy từ params/credentials
      }
      steps {
        withCredentials([string(credentialsId: 'aws-region', variable: 'REGION_OPT')]) {
          withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds']]) {
            sh '''
              set -eu

              # Region
              export AWS_DEFAULT_REGION="${REGION_OPT:-${AWS_DEFAULT_REGION:-ap-southeast-1}}"

              # Chống CRLF khi checkout từ Windows
              sed -i 's/\\r$//' scripts/*.sh || true

              # Kiểm tra SDK & kubectl có sẵn
              aws --version
              kubectl version --client=true || true

              # (Tuỳ chọn) Kiểm tra identity Jenkins đang dùng
              echo "== AWS identity =="
              aws sts get-caller-identity

              # Viết kubeconfig vào $KUBECONFIG (không đụng tới ~/.kube/config trên agent)
              # Nếu cần cross-account/role khác, thêm --role-arn "arn:aws:iam::<acct>:role/<RoleMappedInAwsAuth>"
              aws eks update-kubeconfig \
                --name "${CLUSTER_NAME}" \
                --region "${AWS_DEFAULT_REGION}" \
                --kubeconfig "${KUBECONFIG}" \
                --alias "${CLUSTER_NAME}"

              # Nếu bạn cần ép dùng role đã được map trong aws-auth:
              # aws eks update-kubeconfig --name "${CLUSTER_NAME}" --region "${AWS_DEFAULT_REGION}" \
              #   --kubeconfig "${KUBECONFIG}" --alias "${CLUSTER_NAME}" \
              #   --role-arn "arn:aws:iam::<account-id>:role/<eks-access-role>"

              echo "== Current context =="
              kubectl config current-context || true

              echo "== Cluster nodes =="
              kubectl get nodes
            '''
          }
        }
      }
    }


    stage('Ansible Bootstrap') {
      steps {
        sh '''
          ansible-galaxy collection install kubernetes.core community.kubernetes --force
          ansible-galaxy install -r ansible/requirements.yml || true
          ansible-playbook -i ansible/inventory.ini ansible/playbooks/cluster_bootstrap.yml
        '''
      }
    }

    stage('Helm Deploy App') {
      steps {
        sh '''
          source ./scripts/ecr_login.sh
          ECR_URI=$(terraform -chdir=terraform output -raw ecr_uri)
          ./scripts/render_values.sh helm/myapp/values.yaml image.repository "$ECR_URI/myapp"
          helm upgrade --install myapp helm/myapp -n myapp --create-namespace \
            --set image.tag=v0.1.0
        '''
      }
    }
  }

  post {
    always {
      sh 'kubectl -n myapp get pods || true'
      archiveArtifacts artifacts: 'terraform/*.tfstate*', fingerprint: true, onlyIfSuccessful: false
    }
  }
}
