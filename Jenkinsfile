pipeline {
    agent any
    options {
        buildDiscarder(logRotator(numToKeepStr: '3'));
        timestamps()
    }
    environment {
        prefix= "${JOB_BASE_NAME}_${BUILD_NUMBER}"
        admin_operator_key_pem = credentials('admin_operator_key_pem')
        admin_operator_pem = credentials('admin_operator_pem')
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
                script {
                    // Hardcoding the network name for a temporary basis unit the nework creat REST api is fixed. 
                    //def network_name = env.prefix + "_lte_network"
                    def network_name = "5g_lte_network_jenkins"
                    def agw_name = env.prefix + "_5g_agw"
                    /*
                    Currently we are having issue with tier while creating the networking using REST api.

                    def lteNetworkData = readJSON file: "./config_files/lte_network.json"
                    lteNetworkData.description = "5G Network automation by Jenkins"
                    lteNetworkData.id = network_name
                    lteNetworkData.name = network_name
                    creatNetworkPostMethod(lteNetworkData)
                    */
                    def agwData = readJSON file: "./config_files/agw_data.json"
                    def agw_hardware_id = readFile('./ansible/agw_hw_key.info').trim()
                    def agw_chl_key = readFile('./ansible/agw_chl_key.info').trim()
                    agwData.description = "5G Network automation by Jenkins"
                    agwData.device.hardware_id = agw_hardware_id
                    agwData.device.key.key = agw_chl_key
                    agwData.id = agw_name
                    agwData.name = agw_name
                    add5gAgwPostMethod (network_name, agwData)
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

def creatNetworkPostMethod (data) {
    def jsonData = data.toString()
    sh """
    curl -k --insecure --cert ${admin_operator_pem} --key ${admin_operator_key_pem} -X 'POST' 'https://api.magmasi.wavelabs.in/magma/v1/lte' \
    -H 'accept: application/json' -H 'Content-Type: application/json' -d '${jsonData}'
    """
}

def add5gAgwPostMethod (networkName, data) {
    def jsonData = data.toString()
    sh """
    curl -k --insecure --cert ${admin_operator_pem} --key ${admin_operator_key_pem} -X 'POST' 'https://api.magmasi.wavelabs.in/magma/v1/lte/${networkName}/gateways' \
    -H 'accept: application/json' -H 'Content-Type: application/json' -d '${jsonData}'
    """
}