export KUBE_NAMESPACE="default"
export MPI_CLUSTER_NAME="caesar"
./gen-ssh-key.sh
helm template chart --namespace $KUBE_NAMESPACE --name-template $MPI_CLUSTER_NAME -f values.yaml -f ssh-key.yaml | kubectl -n $KUBE_NAMESPACE delete -f -
helm template chart --namespace $KUBE_NAMESPACE  --name-template $MPI_CLUSTER_NAME -f values.yaml -f ssh-key.yaml | kubectl -n $KUBE_NAMESPACE create -f -
