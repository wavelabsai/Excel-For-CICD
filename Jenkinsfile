pipeline {
    agent any
    options {
        buildDiscarder(logRotator(numToKeepStr: '3'))
    }
    stages {
        stage ('Create the Infra') {
            steps {
                script {
                    try {
                        withCredentials([usernamePassword(credentialsId: 'openstack_user_password', passwordVariable: 'OPENSTACK_PASSWORD', usernameVariable: 'OPENSTACK_USER')]) {
                            dir('terraform') {
                                sh "terraform init -var='openstack_password=${OPENSTACK_PASSWORD}' -input=false"
                                sh "terraform apply -var='openstack_password=${OPENSTACK_PASSWORD}' -auto-approve"
                                sh "chmod 066 ssh-keys/id_ed25519"
                            }
                        }
                    } catch (err) {
                        echo err.getMessage()
                        echo "Error detected, but we will continue." 
                    } finally {
                        dir('terraform') {
                            archiveArtifacts artifacts: 'terraform.tfstate'
                        }
                    }
                }

            }
        }
        stage ('Deploy and upgrade AGW') {
            steps {
                dir('ansible') {
                    sh "ansible-playbook agw_deploy.yaml"
                }
            }
        }
        stage("Input Stage for Infra Destroy") {
            steps {
                script {
                    env.DELETE_INFRA = input message: 'User input required', ok: 'Destroy!',
                            parameters: [choice(name: 'DELETE_INFRA', choices: 'yes\no', description: 'Do you want to delete the infra or not?')]
                }
            }
        }
        stage("Destroy the infra") {
            steps {
                script{
                    try {
                        if (env.DELETE_INFRA == "yes") {
                            withCredentials([usernamePassword(credentialsId: 'openstack_user_password', passwordVariable: 'OPENSTACK_PASSWORD', usernameVariable: 'OPENSTACK_USER')]) {
                                dir('terraform') {
                                    sh "terraform destroy -var='openstack_password=${OPENSTACK_PASSWORD}' -auto-approve"
                                }
                            }
                        }
                    } catch (err) {
                        echo err.getMessage()
                        echo "Error detected, but we will continue." 
                    } finally {
                        deleteDir()
                    }
                }
            }
        }
    }
}