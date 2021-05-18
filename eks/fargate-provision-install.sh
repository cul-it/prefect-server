# Mostly following https://www.eksworkshop.com/beginner/180_fargate/

eksctl create cluster \
--profile rld244-sandbox \
--name test \
--version 1.18 \
--region us-east-1 \
--fargate

kubectl create namespace prefect

eksctl create fargateprofile \
  --profile rld244-sandbox \
  --cluster test \
  --name prefect \
  --namespace prefect

# eksctl create fargateprofile \
#   --profile rld244-sandbox \
#   --cluster test \
#   --name game-2048 \
#   --namespace game-2048

eksctl utils associate-iam-oidc-provider \
  --profile rld244-sandbox \
  --region us-east-1 \
  --cluster test \
  --approve

aws iam create-policy \
  --profile rld244-sandbox \
  --policy-name AWSLoadBalancerControllerIAMPolicy \
  --policy-document https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json

eksctl create iamserviceaccount \
  --profile rld244-sandbox \
  --cluster test \
  --namespace kube-system \
  --name aws-load-balancer-controller \
  --attach-policy-arn arn:aws:iam::327651808033:policy/AWSLoadBalancerControllerIAMPolicy \
  --override-existing-serviceaccounts \
  --approve

kubectl get sa aws-load-balancer-controller -n kube-system -o yaml

kubectl apply -k github.com/aws/eks-charts/stable/aws-load-balancer-controller//crds?ref=master

if [ ! -x ${LBC_VERSION} ]
  then
    tput setaf 2; echo '${LBC_VERSION} has been set.'
  else
    tput setaf 1;echo '${LBC_VERSION} has NOT been set.'
fi

echo 'export LBC_VERSION="v2.0.0"' >>  ~/.bash_profile
.  ~/.bash_profile

helm repo add eks https://aws.github.io/eks-charts

export VPC_ID=$(aws eks describe-cluster \
                --profile rld244-sandbox \
                --name test \
                --query "cluster.resourcesVpcConfig.vpcId" \
                --output text)

export AWS_REGION=us-east-1

helm upgrade -i aws-load-balancer-controller \
    eks/aws-load-balancer-controller \
    -n kube-system \
    --set clusterName=test \
    --set serviceAccount.create=false \
    --set serviceAccount.name=aws-load-balancer-controller \
    --set image.tag="${LBC_VERSION}" \
    --set region=${AWS_REGION} \
    --set vpcId=${VPC_ID}

kubectl -n kube-system rollout status deployment aws-load-balancer-controller

# kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/examples/2048/2048_full.yaml
#
# kubectl -n game-2048 rollout status deployment deployment-2048
#
# kubectl get nodes
#
# kubectl get ingress/ingress-2048 -n game-2048


cd /Users/rld244/cul/projects/prefect-server/helm/prefect-server

helm install my-test-server . -n prefect

kubectl get all -n prefect

kubectl create -f ingress.yaml -n prefect

kubectl get ingress -n prefect


# Clean up
cd /Users/rld244/cul/projects/prefect-server/helm/prefect-server

helm uninstall my-test-server -n prefect

# kubectl delete -f https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/examples/2048/2048_full.yaml

helm uninstall aws-load-balancer-controller \
    -n kube-system

eksctl delete iamserviceaccount \
    --profile rld244-sandbox \
    --cluster test \
    --name aws-load-balancer-controller \
    --namespace kube-system \
    --wait

aws iam delete-policy \
    --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/AWSLoadBalancerControllerIAMPolicy

kubectl delete -k github.com/aws/eks-charts/stable/aws-load-balancer-controller//crds?ref=master

eksctl delete fargateprofile \
  --profile rld244-sandbox \
  --name prefect \
  --cluster test

eksctl delete cluster \
  --profile rld244-sandbox \
  --name test \
  --wait
