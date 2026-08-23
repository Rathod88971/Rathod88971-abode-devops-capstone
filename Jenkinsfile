pipeline {

    agent none

    stages {

        stage('BUILD') {

            agent any

            steps {
                checkout scm

                sh '''
                    docker build \
                    -t abode-web:${BUILD_NUMBER} .
                '''
            }
        }

        stage('TEST') {

            agent {
                label 'test'
            }

            steps {
                sh '''
                    docker rm -f abode-test || true

                    docker run -d \
                      --name abode-test \
                      -p 8080:80 \
                      abode-web:${BUILD_NUMBER}

                    sleep 5

                    curl -f http://localhost:8080

                    docker rm -f abode-test
                '''
            }
        }

        stage('PRODUCTION') {

            agent {
                label 'prod'
            }

            when {
                branch 'master'
            }

            steps {
                sh '''
                    docker rm -f abode-web || true

                    docker run -d \
                      --name abode-web \
                      -p 80:80 \
                      abode-web:${BUILD_NUMBER}
                '''
            }
        }
    }
}
