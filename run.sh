export KUBE_NAMESPACE="default"
export MPI_CLUSTER_NAME="caesar"
./gen-ssh-key.sh

kubectl delete statefulset.apps/caesar-openmpi-laptop-worker service/caesar-openmpi-laptop pod/caesar-openmpi-laptop-master && kubectl delete pvc  kubectl delete pvc scratch-claim

# helm template chart --namespace $KUBE_NAMESPACE --name-template $MPI_CLUSTER_NAME -f values.yaml -f ssh-key.yaml | kubectl -n $KUBE_NAMESPACE delete -f -
# helm template chart --namespace $KUBE_NAMESPACE  --name-template $MPI_CLUSTER_NAME -f values.yaml -f ssh-key.yaml | kubectl -n $KUBE_NAMESPACE create -f -

# mpirun --allow-run-as-root -x LD_LIBRARY_PATH -machinefile ./hostfile -np 16 /opt/caesar/bin/FindSourceMPI -c config.cfg 
