#!groovy
environment {
        AWS_DEFAULT_REGION = 'us-east-2'
        AWS_ACCOUNT_ID = '224768844765'


}

def getBranchType(branchName, tagName) {
    def devPattern = ".*dev"
    def qaPatterns = ".*qa/.*"
    def releasePattern = ".*release/.*"
    def productionPattern = "v.*"
    def prPattern = "PR-.*"

    if (tagName =~ productionPattern) {
        return "PRODUCTION"
    } else if (branchName =~ devPattern) {
        return "DEV"
    } else if (branchName =~ qaPatterns) {
        return "QA"
    } else if (branchName =~ releasePattern) {
        return "STAGE"
    } else if (branchName =~ prPattern) {
        return "PR"
    } else {
        return null;
    }
}


def buildNotify(currentBuild, version, branchType) {
    // build status of null means successful
    def buildStatus =  currentBuild.result ?: 'SUCCESS'
    def previousBuild = currentBuild.previousBuild

    // Default values
    def defaultChannel = 'jenkins-release-updates'
    def alertChannel = 'jenkins-release-alerts'
    def colorCode = '#FF0000'
    def greenColor = "#3BCF00"
    def yellowColor = "#BFC14C"
    def redColor = "#DE0000"

    def subject = "`[CMS]` v${version}"
    def summary = 'summary'

    def channel = 'channel'

    // Override default values based on build status
    if (buildStatus == 'STARTED') {
        colorCode = yellowColor
        summary = "${subject} Started Release to `${branchType}`"
    } else if (buildStatus == 'SUCCESS') {
        colorCode = greenColor
        summary = "${subject} Successfully Released to `${branchType}`"
    } else {
        colorCode = redColor
        summary = "${subject} Unable to Release to `${branchType}`"
    }

    // disable notifications for successful DEV builds

    // Send notifications
    withCredentials(bindings: [string(credentialsId: channel, variable: 'HOOK_URL')]) {
        office365ConnectorSend color: colorCode, message: summary, status: buildStatus, webhookUrl: "${HOOK_URL}"
    }
}


node {
    def app
    def branchType
    def image = "laptopamir/cms"
    def tag
    def version

    try {

        stage('Clone repo'){
            checkout scm
        }

        stage('Determine tag'){
            branchType = getBranchType(env.BRANCH_NAME, env.TAG_NAME)

            if (branchType == 'DEV') {
                version = "${env.BUILD_NUMBER}"
                tag = 'develop-v' + "${env.BUILD_NUMBER}"
            } else if (branchType == 'PR') {
                version = "${env.BUILD_NUMBER}"
                tag = "pr-${env.CHANGE_ID}-v${env.BUILD_NUMBER}"
            } else if (branchType == 'QA') {
                version = ("${env.BRANCH_NAME}"=~/^(qa)\/(\d+\.\d+\.\d+)/)[0][2]
                tag = 'qa-v' + version + ".${env.BUILD_NUMBER}"
            } else if (branchType == 'STAGE') {
                version = ("${env.BRANCH_NAME}"=~/^(release)\/(\d+\.\d+\.\d+)/)[0][2]
                tag = 'release-v' + version
            } else if (branchType == 'PRODUCTION') {
                version = ("${env.TAG_NAME}"=~/^(v)(\d+\.\d+\.\d+)/)[0][2]
                tag = 'release-v' + version
            }

            echo "Current Build Type is ${branchType} with version ${version}"
        }

        if (branchType == 'PRODUCTION') {
            docker.withRegistry('', 'laptopamir'){
                stage('Get image'){
                    app = docker.image("${image}:${tag}")
                    // to be sure that this image exists
                    app.pull()
                }
                stage('Tag image') {
                    app.push('latest')
                }
            }
        }
        else if (branchType && tag) {
            stage('Build image') {
                docker.withRegistry('', 'laptopamir'){
                    app = docker.build("${image}:${tag}")
                }
            }

            stage('AWS') {
                withAWS(credentials:'stg', region:'us-east-2') {

                    sh "docker images list"
                    
                    sh "docker build -t checkedup-stg-cms ."
                    sh "docker tag checkedup-stg-cms:latest 224768844765.dkr.ecr.us-east-2.amazonaws.com/checkedup-stg-cms:${tag}"
                    def login = ecrLogin(registryIds: '224768844765.dkr.ecr.us-east-2.amazonaws.com')
                    sh "docker push 224768844765.dkr.ecr.us-east-2.amazonaws.com/checkedup-stg-cms:${tag}"
                    def images = ecrListImages(repositoryName: 'checkedup-stg-cms')

                    // do something
                }
            }




            // stage('Logging into AWS ECR') {
            //     steps {
            //         script {
            //             sh "aws ecr get-login-password - region ${AWS_DEFAULT_REGION} | docker login - username AWS - password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com"
            //         }
                
            //     }
            // }



            if (branchType != 'PR') {
                stage('Push image'){
                    docker.withRegistry('', 'laptopamir'){
                        app.push(tag)
                    }
                }
            }







        }

        // stage('Deploy'){
        //     def environment

        //     if (branchType == 'DEV'){
        //         environment = 'dev'
        //     } else if (branchType == 'QA'){
        //         environment = 'qa'
        //     } else if (branchType == 'STAGE'){
        //         environment = 'stage'
        //     } else if (branchType == 'PRODUCTION'){
        //         environment = 'prod'
        //     }

        //     if (environment && tag) {
        //         withEnv(['AWS_REGION=us-east-1', 'AWS_DEFAULT_REGION=us-east-1']) {
        //             withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'checkedup-aws',
        //                             accessKeyVariable: 'AWS_ACCESS_KEY_ID', secretKeyVariable: 'AWS_SECRET_ACCESS_KEY']]) {
        //                 ansiblePlaybook(
        //                     playbook: 'ansible/main.yml',
        //                     extraVars: [env: environment, image: "${image}:${tag}"]
        //                 )

        //                 if (environment == 'prod') {
        //                     ansiblePlaybook(
        //                         playbook: 'ansible/main.yml',
        //                         extraVars: [env: 'demo', image: "${image}:${tag}"]
        //                     )
        //                 }
        //             }
        //         }
        //     }
        // }

        // stage('Update Database'){
        //     if (branchType == 'STAGE'){
        //         build('CMS-DB/Stage DB')
        //     }
        // }

    } 
    
    catch (e) {
        currentBuild.result = "FAILURE"
        throw e
    } finally {
        buildNotify(currentBuild, version, branchType)
    }
}