pipeline {
  agent any
  options { timestamps(); ansiColor('xterm') }

  environment {
    REGISTRY = "localhost:5000"     // dùng local registry để test nhanh
    IMAGE    = "myapp"
  }

  stages {
    stage('Checkout') {
      steps { checkout scm }
    }

    stage('Build') {
      steps { sh "mvn -B clean package -DskipTests" }
    }

    stage('Test') {
      steps {
        sh "mvn -B test"
        junit 'target/surefire-reports/*.xml'
      }
    }

    stage('Docker Build & Tag') {
      steps {
        script {
          def sha = sh(returnStdout: true, script: 'git rev-parse --short HEAD').trim()
          sh """
            docker build -t ${env.REGISTRY}/${env.IMAGE}:${sha} .
            docker tag ${env.REGISTRY}/${env.IMAGE}:${sha} ${env.REGISTRY}/${env.IMAGE}:latest
          """
          env.BUILD_TAGGED = sha
        }
      }
    }

    stage('Push Image') {
      steps {
        // Local registry 5000 mặc định không cần login (nếu đánh dấu insecure – xem bước 5)
        sh """
          docker push ${env.REGISTRY}/${env.IMAGE}:${env.BUILD_TAGGED}
          docker push ${env.REGISTRY}/${env.IMAGE}:latest
        """
      }
    }

    stage('Deploy to Staging') {
      when { branch 'main' }
      environment {
        TAG = "latest"
      }
      steps {
        sh "REGISTRY=${env.REGISTRY} IMAGE=${env.IMAGE} TAG=${TAG} bash deploy/staging-deploy.sh"
      }
    }
  }

  post {
    success { echo "Build the URL success: ${env.BUILD_URL}" }
    failure { echo "Build failed! ${env.BUILD_URL}" }
  }
}
