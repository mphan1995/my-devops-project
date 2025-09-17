### `Jenkinsfile`
```groovy
pipeline {
  agent any

  environment {
    AWS_DEFAULT_REGION = credentials('aws-region') ?: 'ap-southeast-1'
    // Nếu không dùng credentials binding cho region, giữ default như trên
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
        withCredentials([[
          $class: 'AmazonWebServicesCredentialsBinding',
          credentialsId: 'aws-creds'
        ]]) {
          sh '''
            aws sts get-caller-identity
            terraform -version || true
            kubectl version --client || true
            helm version || true
            ansible --version || true
          '''
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
          ansible-galaxy install -r ansible/requirements.yml
          ansible-playbook -i ansible/inventory.ini ansible/playbooks/cluster_bootstrap.yml
        '''
      }
    }

    stage('Helm Deploy App') {
      steps {
        sh '''
          source ./scripts/ecr_login.sh
          ECR_URI=$(terraform -chdir=terraform output -raw ecr_uri)
          ./scripts/render_values.sh helm/myapp/values.yaml \
            image.repository $ECR_URI/myapp
          helm upgrade --install myapp helm/myapp -n myapp --create-namespace
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