#!/bin/sh

set -e

# Set your environment variables here
ARGOCD_NAMESPACE="gitops"
ARGOCD_CLUSTER_NAME="argocd"

#############################
## Do not modify anything from this line
#############################

# Print environment variables
echo -e "\n=============="
echo -e "ENVIRONMENT VARIABLES:"
echo -e " * ARGOCD_NAMESPACE: $ARGOCD_NAMESPACE"
echo -e " * ARGOCD_CLUSTER_NAME: $ARGOCD_CLUSTER_NAME"
echo -e "==============\n"

# Check if the user is logged in 
if ! oc whoami &> /dev/null; then
    echo -e "Check. You are not logged out. Please log in and run the script again."
    exit 1
else
    echo -e "Check. You are correctly logged in. Continue..."
    if ! oc project &> /dev/null; then
        echo -e "Current project does not exist, moving to project Default."
        oc project default 
    fi
fi

# Deploy the RHDG operator
echo -e "\n[1/3]Deploying the GitOps operator"
oc process -f gitops/00-operator.yaml| oc apply -f -


echo -n "Waiting for pods ready..."
while [[ $(oc get pods -l control-plane=controller-manager -n openshift-operators -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo -n "." && sleep 1; done; echo -n -e "  [OK]\n"

# Deploy the ArgoCD cluster
echo -e "\n[2/3]Deploying the RHDG cluster"
oc process -f gitops/10-argocd-cluster.yaml \
    -p ARGOCD_NAMESPACE=$ARGOCD_NAMESPACE \
    -p ARGOCD_CLUSTER_NAME=$ARGOCD_CLUSTER_NAME | oc apply -f -

echo -n "Waiting for pods ready..."
while [[ $(oc get pods -l app.kubernetes.io/name=$ARGOCD_CLUSTER_NAME-server -n $ARGOCD_NAMESPACE -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo -n "." && sleep 1; done; echo -n -e "  [OK]\n"

# Deploy the ArgoCD application
echo -e "\n[3/3]Deploying the ArgoCD application"
oc process -f gitops/20-application.yaml \
    -p ARGOCD_NAMESPACE=$ARGOCD_NAMESPACE \
    -p ARGOCD_CLUSTER_NAME=$ARGOCD_CLUSTER_NAME | oc apply -f -
