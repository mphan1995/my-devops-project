pipeline {
  agent {
    docker {
      image 'my-devops-tools:latest'     // tên image bạn build từ Dockerfile trên
      args  '-v /var/run/docker.sock:/var/run/docker.sock'
      reuseNode true
    }
  }

  environment {
    AWS_DEFAULT_REGION = 'ap-southeast-1'
  }
  /* phần stages giữ nguyên như file bạn đang dùng */
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
        // Nếu bạn tạo Secret Text id=aws-region, ta sẽ override
        withCredentials([string(credentialsId: 'aws-region', variable: 'REGION_OPT')]) {
          withCredentials([[
            $class: 'AmazonWebServicesCredentialsBinding',
            credentialsId: 'aws-creds'
          ]]) {
            sh '''
              # nếu REGION_OPT có giá trị thì override
              export AWS_DEFAULT_REGION="${REGION_OPT:-$AWS_DEFAULT_REGION}"

              echo "Using AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION"
              aws sts get-caller-identity
              terraform -version || true
              kubectl version --client || true
              helm version || true
              ansible --version || true
            '''
          }
        }
      }
    }

    stage('Terraform Init/Plan/Apply') {
      steps {
        dir('terraform') {
          sh '''
            terraform init -input=false
            terraform fmt -check
            terraform validate
            terraform plan -input=false -out=tfplan \
              -var="aws_account_id=507737351904" \
              -var="region=${AWS_DEFAULT_REGION}"
            terraform apply -input=false -auto-approve tfplan
          '''
        }
      }
    }

    stage('Configure kubeconfig') {
      steps {
        sh '''
          ./scripts/get_kubeconfig.sh
          kubectl get nodes
        '''
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
