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

    parameters {
      booleanParam(name: 'DESTROY', defaultValue: false, description: 'Destroy all resources first')
    }
    stage('Terraform Destroy (manual)') {
      when { expression { return params.DESTROY == true } }
      steps {
        withCredentials([string(credentialsId: 'aws-region', variable: 'REGION_OPT')]) {
          withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds']]) {
            sh '''
              set -e
              export AWS_DEFAULT_REGION="${REGION_OPT:-$AWS_DEFAULT_REGION}"
              cd terraform
              terraform init -input=false

              # ECR có thể chặn destroy nếu còn image -> xoá cưỡng bức trước (không lỗi cũng OK)
              aws ecr delete-repository --repository-name myapp --force --region "$AWS_DEFAULT_REGION" || true

              terraform destroy -auto-approve \
                -var="aws_account_id=507737351904" \
                -var="region=$AWS_DEFAULT_REGION"
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
        KUBECONFIG   = "${env.WORKSPACE}/kubeconfig"
        CLUSTER_NAME = "my-devops-project-eks"
      }
      steps {
        withCredentials([
          string(credentialsId: 'aws-region', variable: 'REGION_OPT'),
          [$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds'] // đây là user/role có quyền AssumeRole sang jenkins-eks-admin
        ]) {
          sh '''
            set -eu
            export AWS_DEFAULT_REGION="${REGION_OPT:-${AWS_DEFAULT_REGION:-ap-southeast-1}}"

            sed -i 's/\\r$//' scripts/*.sh || true
            aws --version
            kubectl version --client=true || true

            echo "== AWS identity (before assume) =="
            aws sts get-caller-identity

            # Lấy STS credentials khi assume sang role đã được cấp access vào EKS
            CREDS_JSON=$(aws sts assume-role \
              --role-arn "arn:aws:iam::507737351904:role/jenkins-eks-admin" \
              --role-session-name "jenkins-eks-admin-session")

            export AWS_ACCESS_KEY_ID=$(echo "$CREDS_JSON" | jq -r .Credentials.AccessKeyId)
            export AWS_SECRET_ACCESS_KEY=$(echo "$CREDS_JSON" | jq -r .Credentials.SecretAccessKey)
            export AWS_SESSION_TOKEN=$(echo "$CREDS_JSON" | jq -r .Credentials.SessionToken)

            echo "== AWS identity (assumed) =="
            aws sts get-caller-identity

            # Viết kubeconfig với role vừa assume
            aws eks update-kubeconfig \
              --name "${CLUSTER_NAME}" \
              --region "${AWS_DEFAULT_REGION}" \
              --kubeconfig "${KUBECONFIG}" \
              --alias "${CLUSTER_NAME}"

            # Sanity check: có lấy được token không
            aws eks get-token --cluster-name "${CLUSTER_NAME}" --region "${AWS_DEFAULT_REGION}" >/dev/null

            echo "== Current context ==" 
            kubectl --kubeconfig "${KUBECONFIG}" config current-context

            echo "== Cluster nodes ==" 
            kubectl --kubeconfig "${KUBECONFIG}" get nodes
          '''
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
