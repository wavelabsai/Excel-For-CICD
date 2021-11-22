pipeline {
    agent any
    options {
        buildDiscarder(logRotator(numToKeepStr: '3'))
    }
    environment {
        prefix= "${JOB_BASE_NAME}_${BUILD_NUMBER}"
    }
    stages {
        stage ('Create the Infra') {
            steps {
                script {
                    try {
                        withCredentials([usernamePassword(credentialsId: 'openstack_user_password', passwordVariable: 'OPENSTACK_PASSWORD', usernameVariable: 'OPENSTACK_USER')]) {
                            dir('terraform') {
                                sh ("terraform init -var='openstack_password=${OPENSTACK_PASSWORD}' -var='prefix=${env.prefix}' -input=false")
                                sh ("terraform apply -var='openstack_password=${OPENSTACK_PASSWORD}' -var='prefix=${env.prefix}' -auto-approve")
                                sh "chmod 0600 ssh-keys/id_ed25519"
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
        stage ('Configure NMS Dashboard') {
            steps {
                dir('ansible') {
                    sh "ansible-playbook agw_info.yaml"
                }
            }
        }
        stage("Input Stage for Infra Destroy") {
            steps {
                script {
                    env.DELETE_INFRA = input message: 'User input required', ok: 'Destroy!',
                            parameters: [choice(name: 'DELETE_INFRA', choices: 'yes\nno', description: 'Do you want to delete the infra or not?')]
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
                                    sh ("terraform destroy -var='openstack_password=${OPENSTACK_PASSWORD}' -var='prefix=${env.prefix}' -auto-approve")
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