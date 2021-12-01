pipeline {
    agent any
    parameters {
        string(name: 'ARTIFACTID', defaultValue: 'https://artifactory.magmacore.org/artifactory/debian-test/pool/focal-ci/magma_1.7.0-1637259345-3c88ec27_amd64.deb', description: 'Download URL to the Deb package')
        booleanParam(name: 'UPGRADE', defaultValue: true, description: 'Do you want to upgrade to 5G version of AGW?')
        booleanParam(name: 'ABotInt', defaultValue: true, description: 'Do you want to Integrate ABot Test framework?')
    }
    options {
        buildDiscarder(logRotator(numToKeepStr: '3'));
        timestamps()
    }
    environment {
        prefix= "${JOB_BASE_NAME}-${BUILD_NUMBER}"
        admin_operator_key_pem = credentials('admin_operator_key_pem')
        admin_operator_pem = credentials('admin_operator_pem')
        abot_ip = "172.16.6.184"
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
                        echo "Error detected, we will exit here."
                        withCredentials([usernamePassword(credentialsId: 'openstack_user_password', passwordVariable: 'OPENSTACK_PASSWORD', usernameVariable: 'OPENSTACK_USER')]) {
                            dir('terraform') {
                                sh ("terraform destroy -var='openstack_password=${OPENSTACK_PASSWORD}' -var='prefix=${env.prefix}' -auto-approve")
                                archiveArtifacts artifacts: 'terraform.tfstate'
                            }
                        }
                        break
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
                script {
                    def packageVersion = parseUrl(params.ARTIFACTID)
                    if (params.UPGRADE) {
                        dir('ansible') {
                            sh "ansible-playbook agw_deploy.yaml --extra-vars \'magma5gVersion=${packageVersion}\' -vv"
                        }
                    } else {
                        dir('ansible') {
                            sh "ansible-playbook agw_deploy.yaml --skip-tags upgrade5gVersion -vv"
                        }
                    }
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
        stage ('Configure ABot with new MME IP and AGW VM') {
            when { expression { return params.ABotInt } }
            steps {
                script {
                    dir('ansible') {
                        sh "ansible-playbook agw_configure_abot.yaml -vv"
                    }
                    ipDataFromJson = readYaml file: ansible/orc8r_ansible_hosts
                    mmeIP = ipDataFromJson.all.vars.eth1
                    configChangeSta = sh(returnStdout: true, script: """curl -X POST -H "Content-Type: application/json" -d '{"comment":{},"uncomment":{},"update":{"MME1.SecureShell.IPAddress":"${mmeIP}"}}' http://${abot_ip}:5000/abot/api/v5/update_config_properties?filename=/etc/rebaca-test-suite/config/magma/nodes-all.propertie""").trim()
                    configChangeSta = readJSON text: configChangeSta
                    if ( configChangeSta.Status.toString() != "OK" ) {
                        break
                    }
                }
            }
        }
        stage ('Execute Feature File') {
            when { expression { return params.ABotInt } }
            steps {
                script {
                    def execStatus = true
                    runFeatureFile = sh(returnStdout: true, script: """curl --request POST http://${abot_ip}:5000/abot/api/v5/feature_files/execute -d '{"params": "1-s1-setup"}'""").trim()
                    runFeatureFile = readJSON text: runFeatureFile
                    runFeatureFile = runFeatureFile.status.toString()
                    if ( runFeatureFile == "OK" ) {
                        while (execStatus) {
                            execStatus = sh(returnStdout: true, script: """curl --request GET http://${abot_ip}:5000/abot/api/v5/execution_status""").trim()
                            execStatus = readJSON text: execStatus
                            execStatus = execStatus.status
                            println "Executing Feature Files: "
                            sleep time: 30, unit: 'SECONDS'
                        }
                    }
                }
            }
        }
        stage ('Get test result info and download') {
            when { expression { return params.ABotInt } }
            steps {
                script {
                    try {
                        lastArtTimeStamp = sh(returnStdout: true, script: """curl --request GET http://${abot_ip}:5000/abot/api/v5/latest_artifact_name""").trim()
                        lastArtTimeStamp = readJSON text: lastArtTimeStamp
                        echo lastArtTimeStamp.data.latest_artifact_timestamp.toString()
                        lastArtTimeStamp = lastArtTimeStamp.data.latest_artifact_timestamp.toString()
                        lastArtUrl = sh(returnStdout: true, script: """curl --request GET http://${abot_ip}:5000/abot/api/v5/artifacts/download?artifact_name=${lastArtTimeStamp}""").trim()
                        lastArtUrl = readJSON text: lastArtUrl
                        fileUrl = lastArtUrl.result.toString()
                        sh(returnStdout: true, script: """curl ${fileUrl} -o testArtifact.zip""")
                        sh(returnStdout: true, script: """if [ ! -d testArtifact ]; then mkdir testArtifact; fi""")
                        unzip dir: 'testArtifact', glob: '', zipFile: 'testArtifact.zip' 
                        getResult = sh(returnStdout: true, script: """curl --request GET http://${abot_ip}:5000/abot/api/v5/artifacts/execFeatureSummary?foldername=${lastArtTimeStamp}""").trim()
                        getResult = readJSON text: getResult
                        def htmlText = createHtmlTableBody (getResult)
                        writeFile file: 'testArtifact/logs/sut-logs/magma-epc/MME1/index.html', text: htmlText.toString()                        
                    } catch (err) {
                        println err
                        deleteDir()
                    } 
                }
            }
        }
        stage ('Sync ABot test reports to Test Agent') {
            when { expression { return params.ABotInt } }
            steps {
                echo "Create Ansible scripts to sync the reports with test_agent"
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

def parseUrl (url) {
    String[] urlArray = url.split("/");
    String lastPath = urlArray[urlArray.length-1];
    lastPath = lastPath.take(lastPath.lastIndexOf('.'))
    packageVersion = lastPath.substring(lastPath.indexOf("_") + 1)
    return packageVersion
}

def createHtmlTableBody (jsonData) {
    def engine = new groovy.text.SimpleTemplateEngine()
    def tableBody = """
        <!DOCTYPE html>
        <html>
        <style>
        table, th, td {
        border:1px solid black;
        }
        </style>
        <body>
        <h2>A basic HTML table</h2>
        <table style="width:100%">
        <tr>
        <th rowspan = "2">Test Case Name</th>
        <th rowspan = "2">Test Run Result</th>
        <th colspan = "3">Scenario</th>
        <th colspan = "4">Steps</th>
        </tr>
        <tr>
        <th>Failed</th>
        <th>Passed</th>
        <th>Total</th>
        <th>Failed</th>
        <th>Passed</th>
        <th>Skipped</th>
        <th>Total</th>
        </tr>
        <% for(r in jsonData.feature_summary.result.data) { %>
        <tr>
        <td><%= r.featureName %></td>
        <td><%= r.features.status %></td>
        <td><%= r.scenario.failed %></td>
        <td><%= r.scenario.passed %></td>
        <td><%= r.scenario.total %></td>
        <td><%= r.steps.failed %></td>
        <td><%= r.steps.passed %></td>
        <td><%= r.steps.skipped %></td>
        <td><%= r.steps.total %></td>
        </tr>
        <% } %>
        </table>
        </body>
        </html>
        """
  return engine.createTemplate(tableBody).make([jsonData: jsonData])
}