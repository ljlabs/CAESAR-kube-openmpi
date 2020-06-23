
# kube-openmpi: Open MPI jobs on Kubernetes

kube-openmpi provides mainly two things:
- Kubernetes manifest template (powered by [Helm](https://github.com/kubernetes/helm)) to run open mpi jobs on kubernetes cluster. See `chart` directory for details.
- [base docker images on DockerHub](https://hub.docker.com/r/everpeace/kube-openmpi/) to build your custom docker images.  Currently we provide only ubuntu 16.04 based imaages.  To support distributed deep learning workloads, we provides cuda based images, too.  Supported tags are below:

# Supported tags of kube-openmpi base images
- Plain Ubuntu based: `2.1.2-16.04-0.7.0` / `0.7.0`
  - naming convention: `$(OPENMPI_VERSION)-$(UBUNTU_IMAGE_TAG)-$(KUBE_OPENMPI_VERSION)`
    - `$(UBUNTU_IMAGE_TAG)` refers to tags of [ubuntu](https://hub.docker.com/_/ubuntu/)
- Cuda (with cuDNN7) based:
  - cuda8.0: `2.1.2-8.0-cudnn7-devel-ubuntu16.04-0.7.0` / `0.7.0-cuda8.0`
  - cuda9.0: `2.1.2-9.0-cudnn7-devel-ubuntu16.04-0.7.0` / `0.7.0-cuda9.0`
  - cuda9.1: `2.1.2-9.1-cudnn7-devel-ubuntu16.04-0.7.0` / `0.7.0-cuda9.1`
  - naming convention is `$(OPENMPI_VERSION)-$(CUDA_IMAGE_TAG)-$(KUBE_OPENMPI_VERSION)`
    - `$(CUDA_IMAGE_TAG)` refers to tags of [nvidia/cuda](https://hub.docker.com/r/nvidia/cuda/)
  - see [Dockerfile](image/Dockerfile)
- Chainer, Cupy, ChainerMN image:
  - cuda8.0: `0.7.0-cuda8.0-nccl2.1.4-1-chainer4.0.0b4-chainermn1.2.0`
  - cuda9.0: `0.7.0-cuda9.0-nccl2.1.15-1-chainer4.0.0b4-chainermn1.2.0`
  - cuda9.1: `0.7.0-cuda9.1-nccl2.1.15-1-chainer4.0.0b4-chainermn1.2.0`
  - naming convention is `$(KUBE_OPENMPI_VERSION)-$(CUDA_VERSION)-nccl$(NCCL_CUDA80_PACKAGE_VERSION)-chainer$(CHAINER_VERSION)-chainermn$(CHAINER_MN_VERSION)`
  - see [Dockerfile.chainermn](image/Dockerfile.chainermn)

----

- [Quick Start](#quick-start)
- [Use your own custom docker image](#use-your-own-custom-docker-image)
  - [Pull an image from Private Registry](#pull-an-image-from-private-registry)
- [Inject your code to your containers from Github](#inject-your-code-to-your-containers-from-github)
  - [When Your Code In Private Repository](#when-your-code-in-private-repository)
- [Run kube-openmpi cluster as non-root user](#run-kube-openmpi-cluster-as-non-root-user)
- [How to use gang-scheduling (i.e. schedule a group of pods at once)](#how-to-use-gang-scheduling-ie-schedule-a-group-of-pods-at-once)
- [Run ChainerMN Job](#run-chainermn-job)
- [Release Notes](#release-notes)


# Quick Start
## Requirements
- kubectl: follow [the installation step](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
- [helm](https://github.com/kubernetes/helm) client: follow [the installatin step](https://docs.helm.sh/using_helm/#installing-the-helm-client).
- Kubernetes cluster ([minikube](https://github.com/kubernetes/minikube) is super-handy for local test.)


## Generate ssh keys and edit configuration
```
# generate temporary key
$ ./gen-ssh-key.sh

# edit your values.yaml
$ $EDITOR values.yaml
```

## Deploy
```
$ MPI_CLUSTER_NAME=__CHANGE_ME__
$ KUBE_NAMESPACE=__CHANGE_ME_
$ helm template chart --namespace $KUBE_NAMESPACE --name $MPI_CLUSTER_NAME -f values.yaml -f ssh-key.yaml | kubectl -n $KUBE_NAMESPACE create -f -
```

## Run
```
# wait until $MPI_CLUSTER_NAME-master is ready
$ kubectl get -n $KUBE_NAMESPACE po $MPI_CLUSTER_NAME-master

# You can run mpiexec now via 'kubectl exec'!
# hostfile is automatically generated and located '/kube-openmpi/generated/hostfile'
$ kubectl -n $KUBE_NAMESPACE exec -it $MPI_CLUSTER_NAME-master -- mpiexec --allow-run-as-root \
  --hostfile /kube-openmpi/generated/hostfile \
  --display-map -n 4 -npernode 1 \
  sh -c 'echo $(hostname):hello'
 Data for JOB [43686,1] offset 0

 ========================   JOB MAP   ========================

 Data for node: MPI_CLUSTER_NAME-worker-0        Num slots: 2    Max slots: 0    Num procs: 1
        Process OMPI jobid: [43686,1] App: 0 Process rank: 0 Bound: UNBOUND

 Data for node: MPI_CLUSTER_NAME-worker-1        Num slots: 2    Max slots: 0    Num procs: 1
        Process OMPI jobid: [43686,1] App: 0 Process rank: 1 Bound: UNBOUND

 Data for node: MPI_CLUSTER_NAME-worker-2        Num slots: 2    Max slots: 0    Num procs: 1
        Process OMPI jobid: [43686,1] App: 0 Process rank: 2 Bound: UNBOUND

 Data for node: MPI_CLUSTER_NAME-worker-3        Num slots: 2    Max slots: 0    Num procs: 1
        Process OMPI jobid: [43686,1] App: 0 Process rank: 3 Bound: UNBOUND

 =============================================================
MPI_CLUSTER_NAME-worker-1:hello
MPI_CLUSTER_NAME-worker-2:hello
MPI_CLUSTER_NAME-worker-0:hello
MPI_CLUSTER_NAME-worker-3:hello
```

## Scale Up/Down your cluster
MPI workers forms [StatefulSets](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/). So, you can scale up or down the cluster.

```
# scale workers from 4 to 3
$ kubectl -n $KUBE_NAMESPACE scale statefulsets $MPI_CLUSTER_NAME-worker --replicas=3
statefulset "MPI_CLUSTER_NAME-worker" scaled

# Then you can mpiexec again
# hostfile will be updated automatically every 15 seconds in default
$ kubectl -n $KUBE_NAMESPACE exec -it $MPI_CLUSTER_NAME-master -- mpiexec --allow-run-as-root \
  --hostfile /kube-openmpi/generated/hostfile \
  --display-map -n 3 -npernode 1 \
  sh -c 'echo $(hostname):hello'
...
MPI_CLUSTER_NAME-worker-0:hello
MPI_CLUSTER_NAME-worker-2:hello
MPI_CLUSTER_NAME-worker-1:hello
```

## Tear Down

```
$ helm template chart --namespace $KUBE_NAMESPACE --name $MPI_CLUSTER_NAME -f values.yaml -f ssh-key.yaml | kubectl -n $KUBE_NAMESPACE delete -f -
```

# Use your own custom docker image
please edit `image` section in `values.yaml`

```
image:
  repository: yourname/kube-openmpi-based-custom-image
  tag: latest
```

It expects that your custom image is based on our base image ([everpeace/kube-openmpi](https://hub.docker.com/r/everpeace/kube-openmpi/)) and does NOT change any ssh/sshd configurations define in `image/Dockerfile` on your custom image.

Please refer to [Custom ChainerMN image example on kube-openmpi](chainermn-example/README.md) for details.

## Pull an image from Private Registry
Please create a `Secret` of `docker-registry` type to your namespace by referring [here](https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry).

And then, you can specify the secret name in your `values.yaml`:

```
image:
  repository: <your_registry>/<your_org>/<your_image_name>
  tag: <your_tag>
  pullSecrets:
  - name: <docker_registry_secret_name>
```

# Inject your code to your containers from Github
kube-openmpi supports to import your codes hosted by github into your containers.  To do it, please edit `appCodesToSync` section in `values.yaml`.  You can define multiple github repositories.

```
appCodesToSync:
- name: your-app-name
  gitRepo: https://github.com/org/your-app-name.git
  gitBranch: master
  fetchWaitSecond: "120"
  mountPath: /repo
```

## When Your Code In Private Repository
When your code are in private git repository.  The secret repo must be able to access via ssh.  

__Please remember this feature requires `securityContext.runAs: 0` for side-car containers fetching your code into mpi containers.__

### Step 1.
You need to register ssh key to the repo.  I recommend you to set up `Deploy Keys` for your secret repo because it is valid only for the target repository and read-only.

- github: [Managing Deploy Keys | Github Developer Guide](https://developer.github.com/v3/guides/managing-deploy-keys/#deploy-keys)
- bitbucket: [Use access keys | Bitbucket Support](https://confluence.atlassian.com/bitbucket/use-access-keys-294486051.html)

### Step 2.
Create `generic` type `Secret` which has a key `ssh` and its value is the private key.

```
$ kubectl create -n $KUBE_NAMESPACE secret generic <git-sync-cred-name> --from-file=ssh=<deploy-private-key-file>
```
### Step 3.
Then, you can define `appCodesToSync` entries with the secret

```
- name: <your-secret-repo>
  gitRepo: git@<git-server>:<your-org>/<your-secret-repo>.git
  gitBranch: master
  fetchWaitSecond: "120"
  mountPath: <mount-point>
  gitSecretName: <git-sync-cred-name>
```

# Run kube-openmpi cluster as non-root user
At default, kube-openmpi runs your mpi cluster as root user.  However, from security standpoint, you might want to run your mpi-cluster as non-root user.  There is two way to achieve this.

## Use default `openmpi` user and group
[kube-openmpi base docker images on DockerHub](https://hub.docker.com/r/everpeace/kube-openmpi/) ships such normal user `openmpi` with `uid=1000`/`gid=1000`.  To make the user run your mpi-cluster,  edit your `values.yaml` to specify SecurityContext like below:

```
# values.yaml
...
mpiMaster:
  securityContext:
    runAsUser: 1000
    fsGroup: 1000
...
mpiWorkers:
  securityContext:
    runAsUser: 1000
    fsGroup: 1000
```

Then you can run `mpiexec` as `openmpi` user.  You would need to tear down and re-deploy your mpi-cluster if you had kube-openmpi cluster already.

```
$ kubectl -n $KUBE_NAMESPACE exec -it $MPI_CLUSTER_NAME-master -- mpiexec \
  --hostfile /kube-openmpi/generated/hostfile \
  --display-map -n 4 -npernode 1 \
  sh -c 'echo $(hostname):hello'
...
```

## Use your own custom user with custom uid/gid
You need to build your own custom base image because the custom user with your desired uid/gid must exists(embedded) in the docker image.  To do this, just run `make` with several options below.

```
$ cd images
$ make REPOSITORY=<your_org>/<your_repo> SSH_USER=<username> SSH_UID=<uid> SSH_GID=<gid>
```

This creates ubuntu based image, cuda8(cudnn7) image and cuda9(cudnn7) image.

And then, set the `image` in your `values.yaml` and set your uid/gid to `runAsUser`/`fsGroup` as the previous section.

# How to use gang-scheduling (i.e. schedule a group of pods at once)
As stated [kubeflow/tf-operator#165](https://github.com/kubeflow/tf-operator/issues/165), spawning multiple kube-openmpi cluster causes deadlock.  To prevent it,  you might want `gang-scheduling` (i.e schedule multiple pods all together) in kubernetes.  Currently, [kubernetes-incubator/kube-arbitrator](https://github.com/kubernetes-incubator/kube-arbitrator) support it by using `kube-batchd` scheduler and `PodDisruptionBudget`.

Please follow the steps:

1. [deploy `kube-batchd` scheduler](https://github.com/kubernetes-incubator/kube-arbitrator/blob/master/doc/usage/batchd_tutorial.md)

2. Edit `mpiWorkers.customScheduling` section in your `values.yaml` like this.

   ```
   mpiWorkers:
     customScheduling:
       enabled: true
       schedulerName: <your_kube-batchd_scheduler_name>
       podDisruptionBudget:
         enabled: true
   ```

3. Deploy your kube-openmpi cluster.


# Run ChainerMN Job
We published Chainer,ChainerMN(with CuPy and NCCL2) based image. Let's use it.  In this example, we run `train_mnist` example in ChainerMN repo.  If you wanted to build your own docker image.  Please refer to [Custom ChainerMN image example on kube-openmpi](chainermn-example/README.md) for details.

1. edit your `values.yaml` so that
  - kube-openmpi uses the image.
  - allocate `2` mpi workers and assign `1` GPU resource to each mpi worker.
  - add `appCodesToSync` entry to run `train_mnist` example with ChainerMN.

  ```
  image:
    repository: everpeace/kube-openmpi
    tag: 0.7.0-cuda8.0-nccl2.1.4-1-chainer4.0.0b4-chainermn1.2.0
  ...
  mpiWorkers:
    num: 2
    resources:
      limits:
        nvidia.com/gpu: 1
  ...
  appCodesToSync:
  - name: chainermn
    gitRepo: https://github.com/chainer/chainermn.git
    gitBranch: master
    fetchWaitSecond: "120"
    mountPath: /chainermn-examples
    subPath: chainermn/examples
  ...
  ```

2. Deploy your kube-openmpi cluster

  ```
  $ MPI_CLUSTER_NAME=__CHANGE_ME__
  $ KUBE_NAMESPACE=__CHANGE_ME_
  $ helm template chart --namespace $KUBE_NAMESPACE --name $MPI_CLUSTER_NAME -f values.yaml -f ssh-key.yaml | kubectl -n $KUBE_NAMESPACE create -f -
  ```

3. Run `train_mnist` with GPU

  ```
  $ kubectl -n $KUBE_NAMESPACE exec -it $MPI_CLUSTER_NAME-master -- mpiexec --allow-run-as-root \
    --hostfile /kube-openmpi/generated/hostfile \
    --display-map -n 2 -npernode 1 \
    python3 /chainermn-examples/mnist/train_mnist.py -g
  ========================   JOB MAP   ========================

  Data for node: MPI_CLUSTER_NAME-worker-0  Num slots: 8    Max slots: 0    Num procs: 1
         Process OMPI jobid: [28697,1] App: 0 Process rank: 0 Bound: socket 0[core 0[hwt 0-1]]:[BB/../../..][../../../..]

  Data for node: MPI_CLUSTER_NAME-worker-1  Num slots: 8    Max slots: 0    Num procs: 1
         Process OMPI jobid: [28697,1] App: 0 Process rank: 1 Bound: socket 0[core 0[hwt 0-1]]:[BB/../../..][../../../..]

  =============================================================
  ==========================================
  Num process (COMM_WORLD): 2
  Using GPUs
  Using hierarchical communicator
  Num unit: 1000
  Num Minibatch-size: 100
  Num epoch: 20
  ==========================================
  ...
  1           0.224002    0.102322              0.9335         0.9695                    17.1341
  2           0.0733692   0.0672879             0.977967       0.9765                    24.7188
  ...
  20          0.00531046  0.105093              0.998267       0.9799                    160.794
  ```

## Release Notes
### __0.7.0__
- docker base images:
  - fix `init.sh` so that non-root user won't fail to run `init.sh`
- kubernetes manifests:
  - add master pod to compute nodes.  now openmpi jobs can run in master pod.  This enables users to use single-node openmpi jobs.
  
### __0.6.0__
- docker base images:
  - __CMD was changed from `start_sshd.sh` to `init.sh`__.  When `ONE_SHOT` was `true`, `init.sh` will execute user command which as passed an arguments to `init.sh` just after sshd was up.
- kubernetes manifests:
  - `oneShot` mode is supported.  Auto scale down workers feature is also supported.
    - In `mpiMaster.oneShot` mode, `mpiMaster.oneShot.command` will be automatically executed in master once cluster was up.  if `mpiMaster.oneShot.autoScaleDownWorkers` was enabled and `mpiMaster.oneShot.command` successfully completed (i.e. return code was `0`), worker cluster will be scaled down to `0`.

### __0.5.3__
- docker base images
  - cuda9.0 support added.
  - ChainerMN images for each cuda versions(8.0, 9.0, 9.1)
- kubernetes manifests:
  - supported docker registry secret to pull docker images from private docker registry
  - supported fetching codes from private git repositories

### __0.5.2__
- kubernetes manifests:
  - For preventing potential deadlock when scheduling multiple kube-openmpi clusters, `gang-scheduling` (schedule a group of pods all together) for mpi workers is now available via [`kube-batchd`](https://github.com/kubernetes-incubator/kube-arbitrator/blob/master/doc/usage/batchd_tutorial.md) in [`kube-arbitrator`](kubernetes-incubator/kube-arbitrator).

### __0.5.1__
- kubernetes manifests:
  - support user defined `volumes`/`volumeMounts`
  - kube-openmpi managed volume names changed.
- Documents
  - make `Run` step simpler. Changed to use `kubectl exec -it -- mpiexec` directly.

### __0.5.0__
- docker images:
  - `root` can ssh to both mpi-master and mpi-workers when containers run as root
- kubernetes manifests:
  - now mpi cluster runs as `root` at default
  - you can use `openmpi` user as before by setting `runAsUser`/`fsGroup` in `values.yaml`
  - you don't need to dig a tunnel to use `mpiexec` command!
  - documented how to use your custom user with custom uid/gid

### __0.4.0__
- docker images:
  - added `orte_keep_fqdn_hostnames=t` to `openmpi-mca-params.conf`
- kubernetes manifests:
  - now you don't need `CustomPodDNS` feature gate!!
  - `bootstrap` job was removed
  - `hostfile-updater` was introduced.  Now you can scale up/down your mpi cluster dynamically!
    - It runs next to `mpi-master` pod as a side-car container.
  - The path of auto generated `hostfile` was moved to `/kube-openmpi/generated/hostfile`

### __0.3.0__
- docker images:
  - removed s6-overlay init process and introduced self-managed sshd script to support `securityContext` (e.g. `securityContext.runAs`) (#1).
- kubernetes manifests:
  - supported custom `securityContext` (#1)
  - improved mpi-cluster cleanup process
  - fixed broken network-policy maniefst

### __0.2.0__
- docker images:
  - fixed cuda-aware openMPI installation script. added ensure `mca:mpi:base:param:mpi_built_with_cuda_support:value:true` when cuda based image was built.  You can NOT use open MPI with CUDA on `0.1.0`.  So, please use `0.2.0`.
- kubernetes manifests:
  - fixed `resources` in `values.yaml` was ignored.
  - now `workers` can resolve `master` in DNS.

### __0.1.0__
- initial release


# TODO
- [ ] automate the process (create kube-openmpi commnd?)
- [ ] document chart parameters
- [ ] add additional persistent volume claims
