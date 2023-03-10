pipeline
{
    agent any
    
    tools {
        terraform 'terraform'
    }
    
    stages{
        stage('Checkout') {
      steps {
        script {
            checkout([$class: 'GitSCM', branches: [[name: '*/main']], userRemoteConfigs: [[url: 'https://github.com/MitraPaideti/terraform-jenkin.git']]])

        }
      }
    }
        stage("set env variable"){
            steps{
                sh 'export AWS_PROFILE=ilab'
            }
        }
        stage('Get Directory') {
            steps{
                println(WORKSPACE)
            }
        }
        stage('Terraform init'){
            steps{
                sh 'terraform init'
            }
        }
        stage('Terraform Apply'){
            steps{
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: "AWS-access-key",
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY']]) {
                sh 'terraform destroy --auto-approve'
                }
            }
        }
        stage ("Approval Destroy") {
    steps {
        echo "Taking approval from DEV Manager for QA Deployment"
        timeout(time: 7, unit: 'DAYS') {
            input message: 'Do you want to Destroy the Infra', submitter: 'admin'
            }
                }
            }
    // Destroy stage      
        stage ("Terraform Destroy") {
            steps {
                withCredentials([[
                $class: 'AmazonWebServicesCredentialsBinding',
                credentialsId: "AWS-access-key",
                accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                secretKeyVariable: 'AWS_SECRET_ACCESS_KEY']]){
                    sh """
                    terraform destroy --auto-approve
                    """                        
                    // sh 'terraform -chdir="./v.14/test_env" destroy --auto-approve'       
                    }
               }
            }
    }
}
