pipeline {
    agent any
    environment {
        K8S_NAMESPACE = 'k8s'
        IMAGE_NAME = 'mohamedmorad/library-project'
        IMAGE_TAG = 'latest'
        EFS_FILESYSTEM_ID = 'fs-xxxxxxxxxxxxxxxxx'
    }
    stages {
        stage('Clone Repository') {
            steps {
                git branch: 'main',
                    credentialsId: 'github',
                    url: 'https://github.com/Mohamed-Mourad/cls-devops-library.git'
            }
        }
        // stage('Update Deployment Manifest') {
        //     steps {
        //         script {
        //             // Update the image in your backend deployment manifest.
        //             // This example assumes that your backend.yaml contains a line like:
        //             //   image: mohamedmorad/library-project:<old_tag>
        //             // which we replace with the new tag.
        //             sh "sed -i 's|${IMAGE_NAME}:.*|${IMAGE_NAME}:${IMAGE_TAG}|g' k8s/backend.yaml"
        //         }
        //     }
        // }
        stage('Generate Kubeconfig') {
            steps {
                // Generate a temporary kubeconfig file in the workspace
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                  credentialsId: 'aws-credentials']]) {
                      sh 'aws eks --region eu-west-1 update-kubeconfig --name cls-eks-cluster --kubeconfig ./kubeconfig_tmp'
                  }
            }
        }
        stage('Create namespace') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                credentialsId: 'aws-credentials']]) {
                    withEnv(["KUBECONFIG=${env.WORKSPACE}/kubeconfig_tmp"]) {
                        sh '''
                            echo "Creating namespace (if not exists)..."
                            kubectl create namespace ${K8S_NAMESPACE} || echo "Namespace ${K8S_NAMESPACE} already exists"
                        '''
                    }
                }
            }
        }
        stage('Apply kube crt in k8s') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                credentialsId: 'aws-credentials']]) {
                    withEnv(["KUBECONFIG=${env.WORKSPACE}/kubeconfig_tmp"]) {
                        script {
                            // Retrieve the full configmap YAML
                            def configmapYaml = sh(script: "kubectl get configmap kube-root-ca.crt -n kube-public -o yaml", returnStdout: true).trim()
                            
                            // Extract the ca.crt field
                            def caCert = sh(script: "echo '${configmapYaml}' | grep 'ca.crt' | awk '{print \$2}'", returnStdout: true).trim()
        
                            // Check if ca.crt was extracted successfully
                            if (caCert) {
                                // Create or update the configmap with the extracted certificate
                                sh """
                                    kubectl create configmap kube-root-ca.crt --from-literal=ca.crt="${caCert}" -n ${K8S_NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
                                """
                            } else {
                                error("The 'ca.crt' field is missing from the kube-root-ca.crt ConfigMap in the kube-public namespace.")
                            }
                        }
                    }
                }
            }
        }
        stage('Deploy to EKS using Kustomize') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-credentials']]) {
                    withEnv(["KUBECONFIG=${env.WORKSPACE}/kubeconfig_tmp"]) {
                        sh '''
                            echo "Applying manifests using Kustomize to namespace ${K8S_NAMESPACE}..."
                            # Ensure EFS_FILESYSTEM_ID is exported for envsubst
                            export EFS_FILESYSTEM_ID

                            # --- Check/Install Tools (Add only if needed on your agent) ---
                            if ! command -v kustomize &> /dev/null; then
                                echo "Kustomize not found. Installing..."
                                # Replace with appropriate install for your Jenkins agent OS/Arch
                                curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
                                sudo mv kustomize /usr/local/bin/
                                echo "Kustomize installed."
                            fi

                            if ! command -v envsubst &> /dev/null; then
                                echo "envsubst not found. Please install 'gettext' package on the Jenkins agent."
                                # Example for Debian/Ubuntu: sudo apt-get update && sudo apt-get install -y gettext-base
                                exit 1 # Fail if envsubst is missing
                            fi
                            # --- End Tool Check ---

                            echo "EFS Filesystem ID to use: ${EFS_FILESYSTEM_ID}"
                            if [ -z "${EFS_FILESYSTEM_ID}" ] || [ "${EFS_FILESYSTEM_ID}" = "fs-xxxxxxxxxxxxxxxxx" ]; then
                                echo "Error: EFS_FILESYSTEM_ID is not set or is still the placeholder value."
                                exit 1
                            fi


                            echo "Building Kustomize overlay and applying to namespace ${K8S_NAMESPACE}..."
                            # Build the overlay for 'dev'
                            # Build the overlay, substitute EFS ID in StorageClass, apply
                            kustomize build k8s/overlays/dev | envsubst '\$EFS_FILESYSTEM_ID' | kubectl apply -n ${K8S_NAMESPACE} -f -

                            echo "All resources applied via Kustomize to namespace ${K8S_NAMESPACE}."
                        '''
                    }
                }
            }
        }
        stage('Verify Deployment') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                credentialsId: 'aws-credentials']]) {
                    withEnv(["KUBECONFIG=${env.WORKSPACE}/kubeconfig_tmp"]) {
                        // Wait for the backend deployment rollout to complete and list pods.
                        sh 'kubectl rollout status deployment/backend-deployment -n ${K8S_NAMESPACE}'
                        sh 'kubectl get pods -n ${K8S_NAMESPACE}'
                        script {
                            def loadBalancerIP = sh(script: "kubectl get svc -n ${K8S_NAMESPACE} -o jsonpath='{.items[?(@.spec.type==\"LoadBalancer\")].status.loadBalancer.ingress[0].hostname}'", returnStdout: true).trim()
                            def ingressIP = sh(script: "kubectl get ingress -n ${K8S_NAMESPACE} -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}'", returnStdout: true).trim()

                            if (loadBalancerIP) {
                                echo "Your application is available at: http://${loadBalancerIP}"
                            } else if (ingressIP) {
                                echo "Your application is available at: http://${ingressIP}"
                            } else {
                                echo "Could not determine the application URL. Check your Kubernetes services or ingress settings."
                            }
                        }
                    }
                }
            }
        }
    }
    post {
        success {
            echo 'CD Pipeline completed successfully!'
        }
        failure {
            echo 'CD Pipeline failed. Please review the logs.'
        }
        always {
            // Clean up temporary kubeconfig
            sh 'rm -f ./kubeconfig_tmp'
        }
    }
}