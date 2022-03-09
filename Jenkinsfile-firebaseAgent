pipeline {
    agent { label 'agw-build' }
    parameters {
        string(name: 'ARTIFACTID', defaultValue: 'https://artifactory.magmacore.org/artifactory/debian-test/pool/focal-ci/magma_1.7.0-1637259345-3c88ec27_amd64.deb', description: 'Download URL to the Deb package')
        string(name: 'TestCaseName', defaultValue: 'magma-5g', description: 'Mention the test Case that you want to execute.')
        string(name: 'agwIp', defaultValue: '192.16.3.144', description: 'eth0 IP of your AGW instance.')
    }
    options {
        buildDiscarder(logRotator(daysToKeepStr: '2'));
        disableConcurrentBuilds();
        timestamps()
    }
    environment {
        abot_ip = "172.16.5.60"
        testAgentIp = "172.16.5.70"
        resVerdict = "True"
        mailRecipients = "testing@wavelabs.ai"
    }
    stages {
        stage ('Deploy and upgrade AGW') {
            steps {
                script {
                    try {
                        def ansibleInventory = """{all: {hosts: 172}}"""
                        ansInvData = readYaml text: ansibleInventory
                        ansInvData.all.hosts = params.agwIp
                        sh(returnStdout: true, script: """if [ -f ansible/agw_ansible_hosts ]; then rm -rf ansible/agw_ansible_hosts; fi""")
                        writeYaml charset: '', data: ansInvData, file: 'ansible/agw_ansible_hosts'
                        def packageVersion = parseUrl(params.ARTIFACTID)
                        sh "chmod 0600 terraform/ssh-keys/id_ed25519"
                        notifyBuild('STARTED')
                        dir('ansible') {
                            sh "ansible-playbook agw_deploy.yaml --extra-vars \'magma5gVersion=${packageVersion}\' --skip-tags [baseInstall,setupInterface,addUser]"
                        }
                    } catch (err) {
                        println err
                        currentBuild.result = "FAILED"
                        deleteDir()
                        notifyBuild('FAILED')
                        error err
                    } 
                }
            }
        }
        stage ('Execute Feature File') {
            steps {
                script {
                    try {
                        def execStatus = true
                        FeatueFileExecStatus (execStatus)
                        def runFeatureFileurl = "http://${abot_ip}:5000" + '/abot/api/v5/feature_files/execute'
                        def runFeatureFileparams = "{\"params\": \"${params.TestCaseName}\"}"
                        runFeatureFile = sendRestReq(runFeatureFileurl, 'POST', runFeatureFileparams, 'application/json')
                        runFeatureFile = readJSON text: runFeatureFile.content
                        runFeatureFile = runFeatureFile.status.toString()
                        if ( runFeatureFile == "OK" ) {
                            FeatueFileExecStatus (execStatus)
                        } else {
                            error "Error running Feature files."
                        }
                    } catch (err) {
                        println err
                        currentBuild.result = "FAILED"
                        deleteDir()
                        notifyBuild('FAILED')
                        error err
                    }
                }
            }
        }
        stage ('Get test result info and download') {
            steps {
                script {
                    try {
                        def lastArtTimeStampurl = "http://${abot_ip}:5000" + '/abot/api/v5/latest_artifact_name'
                        def lastArtTimeStampparams = ""
                        lastArtTimeStamp = sendRestReq(lastArtTimeStampurl, 'GET', lastArtTimeStampparams, 'application/json')
                        lastArtTimeStamp = readJSON text: lastArtTimeStamp.content
                        echo lastArtTimeStamp.data.latest_artifact_timestamp.toString()
                        lastArtTimeStamp = lastArtTimeStamp.data.latest_artifact_timestamp.toString()

                        if (ffArtifactURL (lastArtTimeStamp)) {
                            sleep 10
                        }
                        fileUrl = ffArtifactURL (lastArtTimeStamp)
                        timeout(5) {
                            waitUntil(initialRecurrencePeriod: 15000) {
                                def statusCode = ""
                                try {
                                    statusCode = sh(script: "curl -o /dev/null -s -w '%{http_code}\\n' ${fileUrl}", returnStdout: true).trim()
                                    if ( statusCode == "200" ) {
                                        sh(script: "curl ${fileUrl} -o testArtifact.zip", returnStdout: true)
                                        return true 
                                    } else {
                                        println "Artifact is not ready, http status code is : ${statusCode}"
                                        return false
                                    }
                                } catch (exception) {
                                    println exception
                                    return false
                                }
                            }
                        }
                        //sh(returnStdout: true, script: """curl ${fileUrl} -o testArtifact.zip""")
                        sh(returnStdout: true, script: """if [ ! -d testArtifact ]; then mkdir testArtifact; fi""")
                        sh(script: "unzip testArtifact.zip -d testArtifact", retrunStdout: true)
                        //unzip dir: 'testArtifact', glob: '', zipFile: 'testArtifact.zip'
                        uploadLogsToGit(packageVersion)
                        def getResulturl = "http://${abot_ip}:5000" + "/abot/api/v5/artifacts/execFeatureSummary?foldername=${lastArtTimeStamp}"
                        def getResultparams = ""
                        getResult = sendRestReq(getResulturl, 'GET', getResultparams, 'application/json')
                        getResult = readJSON text: getResult.content
                        for ( res in getResult.feature_summary.result.data) {
                            if (res.features.status == "failed" ) {
                                resVerdict = "False"
                            }
                        }
                        sh(returnStdout: true, script: """if [ ! -d testResult ]; then mkdir testResult; fi""")
                        writeFile file: 'testResult/test_verdict', text: resVerdict
                        def tableBody = readFile("config_files/test_report.html")
                        def headHtml = readFile("config_files/test_report_first_part.html")
                        def ffMappingData = readJSON file: "config_files/tc_mapping.json"
                        createHtmlTableBody (ffMappingData, getResult, tableBody, headHtml, packageVersion)
                    } catch (err) {
                        println err
                        //currentBuild.result = "FAILED"
                        //deleteDir()
                        //notifyBuild('FAILED')
                        //error err
                    } 
                }
            }
        }
        stage ('Sync ABot test reports to Test Agent') {
            steps {
                script {
                    try {
                        sh "rm -rf ansible/agw_ansible_hosts"
                        def ansibleInventory = """{all: {hosts: 172}}"""
                        ansInvData = readYaml text: ansibleInventory
                        ansInvData.all.hosts = testAgentIp
                        writeYaml charset: '', data: ansInvData, file: 'ansible/agw_ansible_hosts'
                        dir ('ansible') {
                            sh "ansible-playbook transfer_test_result.yaml"
                        }
                        currentBuild.result = "SUCCESS"
                    } catch (err) {
                        println err
                        deleteDir()
                        notifyBuild('FAILED')
                        error err
                    } finally {
                        notifyBuild(currentBuild.result)
                        deleteDir()
                    }
                }
            }
        }
    }
}

def ffArtifactURL (lastArtTimeStamp) {
    def lastArtUrlurl = "http://${abot_ip}:5000" + "/abot/api/v5/artifacts/download?artifact_name=${lastArtTimeStamp}"
    def lastArtUrlparams = ""
    lastArtUrl = sendRestReq(lastArtUrlurl, 'GET', lastArtUrlparams, 'application/json') 
    lastArtUrl = readJSON text: lastArtUrl.content
    println lastArtUrl.toString()
    fileUrl = lastArtUrl.result.toString()
    fileUrlstatus = lastArtUrl.status.toString()
    if (fileUrlstatus == 'OK') {
        return fileUrl
    } 
}

def FeatueFileExecStatus (execStatus) {
    while (execStatus) {
        def execStatusurl = "http://${abot_ip}:5000" + '/abot/api/v5/execution_status'
        def execStatusparams = ""
        execStatus = sendRestReq(execStatusurl, 'GET', execStatusparams, 'application/json')
        execStatus = readJSON text: execStatus.content
        execStatus = execStatus.status
        println "Executing Feature Files: ${params.TestCaseName}"
        sleep time: 20, unit: 'SECONDS'
    }
}

def parseUrl (url) {
    String[] urlArray = url.split("/");
    String lastPath = urlArray[urlArray.length-1];
    lastPath = lastPath.take(lastPath.lastIndexOf('_'))
    packageVersion = lastPath.substring(lastPath.indexOf("_") + 1)
    return packageVersion
}

@NonCPS
def createHtmlTableBody (ffMappingData, jsonData, html, html1, packageVersion) {
    ffMappingData.each { ffName, data ->
        jsonData.feature_summary.result.data.each { 
            if ( it.featureName == ffName ) {
                it.featureName = it.featureName.minus(".feature")
                it.mgmaTcType = data.Tctype
                it.magmaTestId = data.testid
                if ( it.features.status.equalsIgnoreCase("passed") ) {
                    it.features.status = "PASS"
                } else {
                    it.features.status = "FAIL"
                }
            }
        }
    }
    jsonData.feature_summary.result.data = jsonData.feature_summary.result.data.sort { it.mgmaTcType }
    def engine = new groovy.text.SimpleTemplateEngine()
    def htmlText = engine.createTemplate(html).make([jsonData: jsonData, packageVersion: packageVersion])
    fullhtml = html1.toString() + htmlText.toString()
    println fullhtml
    writeFile file: 'testResult/index.html', text: fullhtml
}

def sendRestReq(def url, def method = 'GET', def data = null, type = null, headerKey = null, headerVal = null) {
    try{
        def response = null
        if (null == url || url.toString().trim().isEmpty()) return response
        method = method.toUpperCase()
        switch (method) {
            case 'GET':
                response = httpRequest quiet: true, httpMode: method, ignoreSslErrors: true,  url: url, wrapAsMultipart: false
                break
            case 'POST':
            case 'PUT':
            case 'DELETE':
                if (null == data) {
                    response = httpRequest quiet: true, httpMode: method, ignoreSslErrors: true, url: url, wrapAsMultipart: false
                } else if (headerKey != null && headerVal != null){
                    // if (null == type || type.toString().trim().isEmpty()) return response
                    response = httpRequest quiet: true, httpMode: method, ignoreSslErrors: true, url: url, requestBody: "${data}", wrapAsMultipart: false, customHeaders: [[maskValue: false, name: 'Content-Type', value: type], [maskValue: false, name: "${headerKey}", value: "${headerVal}"]]
                }
                else {
                    if (null == type || type.toString().trim().isEmpty()) return response
                    response = httpRequest quiet: true, httpMode: method, ignoreSslErrors: true, url: url, requestBody: "${data}", wrapAsMultipart: false, customHeaders: [[maskValue: false, name: 'Content-Type', value: type]]
                }
                break
            default:
                break
                return response
        }
        return response
    } catch(Exception ex) {
        return null
    }
}

def uploadLogsToGit (packageVersion) {
    sh(returnStdout: true, script: """if [ ! -d firebaseagentrepo ]; then mkdir firebaseagentrepo; fi""")
    dir ('firebaseagentrepo') {
        git "https://github.com/wavelabsai/firebaseagentreport.git"
        sh "cp ../testArtifact/logs/sut-logs/magma-epc/AMF1/mme.log mme-${packageVersion}.log"
        sh "cp ../testArtifact/logs/sut-logs/magma-epc/AMF1/syslog syslog-${packageVersion}"
        sh "git config user.email 'tapas.mishra@wavelabs.ai'"
        sh "git config user.name 'Tapas Mishra'"
        sh "git add . && git commit -am 'Adding report files for the version ${packageVersion}'"
        withCredentials([gitUsernamePassword(credentialsId: 'github_token', gitToolName: 'Default')]) {
            sh "git push --set-upstream origin master"
        }
    }
}

def notifyBuild(String buildStatus = 'STARTED') {
    def details = ""
    buildStatus = buildStatus ?: 'SUCCESS'

    def subject = "Job '${env.JOB_NAME}': ${buildStatus} for the AGW artifact ID - ${packageVersion}"
    if (buildStatus == 'STARTED') {
        details = """<p>STARTED: Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]':</p><p>Check console output at &QUOT;<a href='${env.BUILD_URL}/console'>${env.JOB_NAME} [${env.BUILD_NUMBER}]</a>&QUOT;</p>"""
    } else if (buildStatus == 'SUCCESS') {
        details = """<p>COMPLETED: Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]':</p><p>Check console output at &QUOT;<a href='${env.BUILD_URL}/console'>${env.JOB_NAME} [${env.BUILD_NUMBER}]</a>&QUOT;</p>"""
    } else {
        details = """<p>FAILED: Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]':</p><p>Check console output at &QUOT;<a href='${env.BUILD_URL}/console'>${env.JOB_NAME} [${env.BUILD_NUMBER}]</a>&QUOT;</p>"""
    }
    emailext (
        mimeType: 'text/html',
        subject: "[Jenkins] ${subject}",
        body: "${details}",
        to: "${env.mailRecipients}"
    )
}
