Accelerated Computing with Red Hat OpenShift Container Platform 4 and Nvidia Tesla GPU

Add a GPU Node
View the existing nodes, machines, and machine sets.

$ oc get nodes
NAME                                         STATUS   ROLES    AGE    VERSION
ip-10-0-128-195.us-east-2.compute.internal   Ready    master   2d     v1.13.4+9b19d73a0
ip-10-0-130-109.us-east-2.compute.internal   Ready    worker   2d     v1.13.4+9b19d73a0
ip-10-0-146-247.us-east-2.compute.internal   Ready    worker   2d     v1.13.4+9b19d73a0
ip-10-0-155-131.us-east-2.compute.internal   Ready    master   2d     v1.13.4+9b19d73a0
ip-10-0-172-69.us-east-2.compute.internal    Ready    master   2d1h   v1.13.4+9b19d73a0
ip-10-0-173-178.us-east-2.compute.internal   Ready    worker   2d     v1.13.4+9b19d73a0

$ oc get machines -n openshift-machine-api
NAME                                             INSTANCE              STATE     TYPE         REGION      ZONE         AGE
cluster-aus-9195-jg5lt-master-0                  i-0ceb008caaf39a24c   running   m4.xlarge    us-east-2   us-east-2a   2d1h
cluster-aus-9195-jg5lt-master-1                  i-0ec0821f2147261fa   running   m4.xlarge    us-east-2   us-east-2b   2d1h
cluster-aus-9195-jg5lt-master-2                  i-0dcb0ed63c1b5cb96   running   m4.xlarge    us-east-2   us-east-2c   2d1h
cluster-aus-9195-jg5lt-worker-us-east-2a-n87sn   i-05600905386b59947   running   m5.2xlarge   us-east-2   us-east-2a   2d1h
cluster-aus-9195-jg5lt-worker-us-east-2b-65q5f   i-0218c84d5f14c2b14   running   m5.2xlarge   us-east-2   us-east-2b   2d1h
cluster-aus-9195-jg5lt-worker-us-east-2c-9xtkk   i-00ed15f28a8b685c5   running   m5.2xlarge   us-east-2   us-east-2c   2d1h

$ oc get machinesets -n openshift-machine-api
NAME                                       DESIRED   CURRENT   READY   AVAILABLE   AGE
cluster-aus-9195-jg5lt-worker-us-east-2a   1         1         1       1           2d1h
cluster-aus-9195-jg5lt-worker-us-east-2b   1         1         1       1           2d1h
cluster-aus-9195-jg5lt-worker-us-east-2c   1         1         1       1           2d1h

Copy an existing worker machine set definition for a GPU-enabled worker machine set definition.

$ oc get machineset cluster-aus-9195-jg5lt-worker-us-east-2a -n openshift-machine-api -o json > cluster-aus-9195-jg5lt-worker-us-east-2a.json

$ oc get machineset cluster-aus-9195-jg5lt-worker-us-east-2a -n openshift-machine-api -o json > cluster-aus-9195-jg5lt-gpu-us-east-2a.json

Make the following changes to the new machine set definition:
Change the instance type of the new machine set definition to p3, which includes an Nvidia Tesla V100 GPU.
Read more about AWS P3 instance types: https://aws.amazon.com/ec2/instance-types/#Accelerated_Computing
Change the name and self link to a unique name that identifies the new machine set.
Delete the status section from the definition.

$ jq .spec.template.spec.providerSpec.value.instanceType cluster-aus-9195-jg5lt-gpu-us-east-1a.json
"p3.2xlarge"

$ diff cluster-aus-9195-jg5lt-worker-us-east-2a.json cluster-aus-9195-jg5lt-gpu-us-east-2a.json
10c10
<         "name": "cluster-aus-9195-jg5lt-worker-us-east-2a",
---
>         "name": "cluster-aus-9195-jg5lt-gpu-us-east-2a",
13c13
<         "selfLink": "/apis/machine.openshift.io/v1beta1/namespaces/openshift-machine-api/machinesets/cluster-aus-9195-jg5lt-worker-us-east-2a",
---
>         "selfLink": "/apis/machine.openshift.io/v1beta1/namespaces/openshift-machine-api/machinesets/cluster-aus-9195-jg5lt-gpu-us-east-2a",
23c23
<                 "machine.openshift.io/cluster-api-machineset": "cluster-aus-9195-jg5lt-worker-us-east-2a"
---
>                 "machine.openshift.io/cluster-api-machineset": "cluster-aus-9195-jg5lt-gpu-us-east-2a"
33c33
<                     "machine.openshift.io/cluster-api-machineset": "cluster-aus-9195-jg5lt-worker-us-east-2a"
---
>                     "machine.openshift.io/cluster-api-machineset": "cluster-aus-9195-jg5lt-gpu-us-east-2a"
62c62
<                         "instanceType": "m5.2xlarge",
---
>                         "instanceType": "p3.2xlarge",
131,137d130
<     },
<     "status": {
<         "availableReplicas": 1,
<         "fullyLabeledReplicas": 1,
<         "observedGeneration": 1,
<         "readyReplicas": 1,
<         "replicas": 1

Create the new machine set.

$ oc create -f cluster-aus-9195-jg5lt-gpu-us-east-2a.json
machineset.machine.openshift.io/cluster-aus-9195-jg5lt-gpu-us-east-1a created

$ oc -n openshift-machine-api get machinesets | grep gpu
cluster-aus-9195-jg5lt-gpu-us-east-2a      1         1                             45s

The machine set replica count is set to “1” so a new machine is created automatically. View the new machine.

$ oc -n openshift-machine-api get machines | grep gpu
cluster-aus-9195-jg5lt-gpu-us-east-2a-9vw7p      i-0e63046e983d721e0   running   p3.2xlarge   us-east-2   us-east-2a   23s

View the node and its labels.

$ oc -n openshift-machine-api get machines | grep gpu
cluster-aus-9195-jg5lt-gpu-us-east-2a-9vw7p      i-0e63046e983d721e0   running   p3.2xlarge   us-east-2   us-east-2a   23s

$ oc get node ip-10-0-138-78.us-east-2.compute.internal -o json | jq .metadata.labels
{
  "beta.kubernetes.io/arch": "amd64",
  "beta.kubernetes.io/instance-type": "p3.2xlarge",
  "beta.kubernetes.io/os": "linux",
  "failure-domain.beta.kubernetes.io/region": "us-east-2",
  "failure-domain.beta.kubernetes.io/zone": "us-east-2a",
  "kubernetes.io/hostname": "ip-10-0-138-78",
  "node-role.kubernetes.io/worker": "",
  "node.openshift.io/os_id": "rhcos",
  "node.openshift.io/os_version": "4.1"
}

Configure the GPU

Deploy the Node Feature Discovery Operator

The Node Feature Discovery operator identifies hardware device features in nodes. Clone the git repo.

$ git init
$ git config --global user.email "jliberma@redhat.com"
$ git config --global user.name "Jacob Liberman"
$ git config --list
$ git clone https://github.com/openshift/cluster-nfd-operator

View the cluster-nfd-operator container image tags.

$ skopeo inspect docker://quay.io/zvonkok/cluster-nfd-operator | jq ".Tag , .RepoTags"
"latest"
[
  "v0.0.1",
  "v4.1",
  "p3",
  "e2e",
  "operand",
  "latest",
  "configmap",
  "nvidia-label"
]

Update the 0700_cr.yaml manifest to use the 4.1 tagged version or “latest.”

$ cat cluster-nfd-operator/manifests/0700_cr.yaml
apiVersion: nfd.openshift.io/v1alpha1
kind: NodeFeatureDiscovery
metadata:
  name: nfd-master-server
  namespace: REPLACE_NAMESPACE
spec:
  namespace: openshift-nfd
  image: quay.io/zvonkok/node-feature-discovery:v4.1

Build the NFD operator with make.

$ cd cluster-nfd-operator
$ make deploy


View the running NFD pods.

$ oc -n openshift-nfd get pods
NAME               READY   STATUS    RESTARTS   AGE
nfd-master-gq9wk   1/1     Running   0          30s
nfd-master-hkk2q   1/1     Running   0          30s
nfd-master-nvnlq   1/1     Running   0          30s
nfd-worker-4z767   1/1     Running   2          29s
nfd-worker-flz8d   1/1     Running   2          29s
nfd-worker-ghmd2   1/1     Running   2          29s
nfd-worker-qz2nl   1/1     Running   2          29s

View the Nvidia GPU feature discovered by the NFD operator.
It has the PCI ID 10de.

$ oc describe node ip-10-0-138-78.us-east-2.compute.internal | egrep 'Roles|pci'
Roles:              worker
                    feature.node.kubernetes.io/pci-1013.present=true
                    feature.node.kubernetes.io/pci-10de.present=true
                    feature.node.kubernetes.io/pci-1d0f.present=true

Deploy the Special Resource Operator

Clone the special resource operator repository.

$ cd ~
$ git clone git@github.com:zvonkok/special-resource-operator.git

Build the special resource operator with “make deploy.”

$ cd special-resource-operator/
$ make deploy

View the special resource detected by the operator.

$ oc get specialresources --all-namespaces
NAMESPACE                NAME   AGE
openshift-sro-operator   gpu    3m47s

View the pods created by the operator. They run as a daemon set that loads a driver pod and sets the SELinux security context for the device.

$ oc get pods -n openshift-sro
NAME                                   READY   STATUS      RESTARTS   AGE
nvidia-device-plugin-daemonset-6t2tf   1/1     Running     0          2m10s
nvidia-device-plugin-validation        0/1     Completed   0          104s
nvidia-driver-daemonset-jgvbf          1/1     Running     0          3m47s
nvidia-driver-validation               0/1     Completed   0          3m11s

View the logs of the validation pod executed by the special operator.

$ oc logs nvidia-device-plugin-validation -n openshift-sro
[Vector addition of 50000 elements]
Copy input data from the host memory to the CUDA device
CUDA kernel launch with 196 blocks of 256 threads
Copy output data from the CUDA device to the host memory
Test PASSED
Done

It runs a simple vector addition to verify a pod can use the GPU.
Connect to the device plugin daemonset pod and run nvidia-smi to verify communication with the GPU.

$ oc project openshift-sro
Now using project "openshift-sro" on server "https://api.cluster-aus-9195.sandbox311.opentlc.com:6443".

$ oc rsh nvidia-device-plugin-daemonset-6t2tf nvidia-smi
Sun Sep  1 04:01:54 2019       
+-----------------------------------------------------------------------------+
| NVIDIA-SMI 430.26       Driver Version: 430.26       CUDA Version: N/A      |
|-------------------------------+----------------------+----------------------+
| GPU  Name        Persistence-M| Bus-Id        Disp.A | Volatile Uncorr. ECC |
| Fan  Temp  Perf  Pwr:Usage/Cap|         Memory-Usage | GPU-Util  Compute M. |
|===============================+======================+======================|
|   0  Tesla V100-SXM2...  On   | 00000000:00:1E.0 Off |                    0 |
| N/A   34C    P0    22W / 300W |      0MiB / 16160MiB |      0%      Default |
+-------------------------------+----------------------+----------------------+
                                                                               
+-----------------------------------------------------------------------------+
| Processes:                                                       GPU Memory |
|  GPU       PID   Type   Process name                             Usage      |
|=============================================================================|
|  No running processes found                                                 |
+-----------------------------------------------------------------------------+

Run an Nvidia Container

Run nvidia-smi in a container to test

Create a pod definition for a nvidia-smi container.

$ cat nvidia-smi.yaml
apiVersion: v1
kind: Pod
metadata:
  name: nvidia-smi
  namespace: openshift-sro
spec:
  tolerations:
    - key: nvidia.com/gpu
      operator: Exists
      effect: NoSchedule
  serviceAccount: nvidia-device-plugin
  serviceAccountName: nvidia-device-plugin
  readOnlyRootFilesystem: true
  restartPolicy: OnFailure
  containers:
  - name: nvidia-smi
    image: nvidia/cuda
    env:
      - name: NVIDIA_VISIBLE_DEVICES
        value: all
      - name: NVIDIA_DRIVER_CAPABILITIES
        value: "compute,utility"
      - name: NVIDIA_REQUIRE_CUDA  
        value: "cuda>=5.0"
    securityContext:
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
    command: [ nvidia-smi ]
    resources:
      limits:
        nvidia.com/gpu: 1 # requesting 1 GPU

Create the pod.

$ oc create -f nvidia-smi.yaml

View the pod logs to verify the kube-scheduler placed the pod on the GPU-enabled node.

$ oc logs nvidia-smi
Mon Sep  2 04:03:31 2019       
+-----------------------------------------------------------------------------+
| NVIDIA-SMI 430.26       Driver Version: 430.26       CUDA Version: 10.2     |
|-------------------------------+----------------------+----------------------+
| GPU  Name        Persistence-M| Bus-Id        Disp.A | Volatile Uncorr. ECC |
| Fan  Temp  Perf  Pwr:Usage/Cap|         Memory-Usage | GPU-Util  Compute M. |
|===============================+======================+======================|
|   0  Tesla V100-SXM2...  On   | 00000000:00:1E.0 Off |                    0 |
| N/A   36C    P0    25W / 300W |      0MiB / 16160MiB |      1%      Default |
+-------------------------------+----------------------+----------------------+
                                                                               
+-----------------------------------------------------------------------------+
| Processes:                                                       GPU Memory |
|  GPU       PID   Type   Process name                             Usage      |
|=============================================================================|
|  No running processes found                                                 |
+-----------------------------------------------------------------------------+

Run the resnet50 tensorflow benchmark
Download and run a tensorflow pod for NGC.
NGC is Nvidia’s curated registry for GPU-optimized container images.
Downloading containers from NGC requires a login.
Register for NGC here: https://ngc.nvidia.com/catalog/landing

$ sudo podman login nvcr.io
Username: $oauthtoken
Password:
a3I4dXNyYWZtcmQwODlpaHFuMnU1aHRrdWo6MzY4YjFiMGYtMDY3OS00N2VjLTg3MzUtNzA4NWM0ZDI2Njk1

Tensorflow is an open source machine learning library. View the repo tags and labels on the tensorflow images on NGC.

$ skopeo inspect docker://nvcr.io/nvidia/tensorflow:18.02-py3 | jq '.Labels , .RepoTags'

Pull the latest tensorflow image. 

$ sudo podman pull nvcr.io/nvidia/tensorflow:19.08-py3

Create a pod definition file for the resnet50 model.
Resnet50 is a convolutional neural network model for image recognition. It is commonly used to benchmark GPU performance.

$ cat << EOF > tflow-resnet50.yaml
apiVersion: v1
kind: Pod
metadata:
  name: resnet50
  namespace: openshift-sro
spec:
  tolerations:
    - key: nvidia.com/gpu
      operator: Exists
      effect: NoSchedule
  serviceAccount: nvidia-device-plugin
  serviceAccountName: nvidia-device-plugin
  readOnlyRootFilesystem: true
  restartPolicy: OnFailure
  containers:
  - name: tensorflow-resnet50
    image: nvcr.io/nvidia/tensorflow:19.08-py3
    env:
      - name: NVIDIA_VISIBLE_DEVICES
        value: all
      - name: NVIDIA_DRIVER_CAPABILITIES
        value: "compute,utility"
      - name: NVIDIA_REQUIRE_CUDA  
        value: "cuda>=5.0"
    securityContext:
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
    command: [ "/bin/sh" ]
    args: [ "-c", "python nvidia-examples/cnn/resnet.py --layers=50 --precision=fp16"]
    resources:
      limits:
        nvidia.com/gpu: 1 # requesting 1 GPU
EOF

Create the resnet50 pod.

$ oc create -f tflow-resnet50.yaml

$ oc get pods | grep resnet
resnet50                               1/1     Running     0          67s

View the pod logs to see benchmark results.

$ oc logs resnet50 | tail -n 22
TF 1.14.0
Script arguments:
  --layers 50
  --batch_size 256
  --num_iter 90
  --iter_unit epoch
  --display_every 10
  --precision fp16
  --use_xla False
  --predict False
Training
  Step Epoch Img/sec   Loss  LR
     1   1.0    27.0  7.700  8.672 2.00000
    10  10.0   344.4  3.991  4.963 1.62000
    20  20.0   864.8  0.029  1.006 1.24469
    30  30.0   865.3  0.000  0.973 0.91877
    40  40.0   866.3  0.000  0.963 0.64222
    50  50.0   865.9  0.000  0.954 0.41506
    60  60.0   868.9  0.000  0.948 0.23728
    70  70.0   868.0  0.000  0.944 0.10889
    80  80.0   865.8  0.000  0.943 0.02988
    90  90.0   700.8  0.000  0.943 0.00025



Resources
AWS Adds Nvidia GPUs: https://aws.amazon.com/blogs/aws/new-amazon-ec2-instances-with-up-to-8-nvidia-tesla-v100-gpus-p3/
Accelerated Computing with Nvidia GPU on OpenShift https://docs.nvidia.com/datacenter/kubernetes/openshift-on-gpu-install-guide/index.html
OpenShift 4 Architecture https://access.redhat.com/documentation/en-us/openshift_container_platform/4.1/html/architecture/index
# ocp4-gpu-aws
