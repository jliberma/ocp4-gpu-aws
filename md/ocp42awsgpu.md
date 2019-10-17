# Creating a GPU-enabled node with Red Hat OpenShift Container Platform 4.2 in Amazon EC2

OpenShift Container Platform 4 uses the [Machine API operator](https://github.com/openshift/machine-api-operator) to fully automate infrastructure provisioning. The Machine API provides full stack infrastructure automation on public or private clouds.

With the release of [OpenShift Container Platform 4.2](https://www.redhat.com/en/about/press-releases/red-hat-expands-kubernetes-developer-experience-newest-version-red-hat-openshift-4), administrators can easily define GPU-enabled nodes in EC2 using the Machine API and the Node Feature Discovery operator.

These instructions assume that you have OpenShift Container Platform 4 installed in AWS using the [Installer Provided Infrastructure](https://cloud.redhat.com/openshift/install/aws/installer-provisioned) (IPI) installation method.

## Machines and Machine Sets

The Machine API operator defines several custom resources to manage nodes as OpenShift objects. These include Machines and MachineSets.

* A *Machine* defines instances with a desired configuration in a given cloud provider. 
* A *MachineSet* ensures that the specified number of machines exist on the provider. A MachineSet can scale machines up and down, providing self-healing functionality for the infrastructure.

The Machine/MachineSet abstraction allows OpenShift Container Platform to manage nodes the same way it manages pods in replica sets. They can be created, deleted, updated, scaled, and destroyed from the same object definition.

In this blog post we copy and modify a default worker MachineSet configuration to create a GPU-enabled MachineSet (and Machines) for the AWS EC2 cloud provider. 

**NOTE**: This blog post shows how to deploy a GPU-enabled node running Red Hat Enterprise Linux CoreOS. With OpenShift Container Platform 4.2, GPUs are supported in Red Hat Enterprise Linux (RHEL) 7 nodes only. This process is not supported. Please see the [release notes](https://access.redhat.com/documentation/en-us/openshift_container_platform/4.2/html-single/release_notes/index) for details.

## Add a GPU Node

First view the existing nodes, Machines, and MachineSets. 

Each node is an instance of a machine definition with a specific AWS region and OpenShift role.

```
$ oc get nodes
NAME                                         STATUS   ROLES    AGE   VERSION
ip-10-0-131-156.us-east-2.compute.internal   Ready    master   21m   v1.14.6+c07e432da
ip-10-0-132-241.us-east-2.compute.internal   Ready    worker   16m   v1.14.6+c07e432da
ip-10-0-144-128.us-east-2.compute.internal   Ready    master   21m   v1.14.6+c07e432da
ip-10-0-151-24.us-east-2.compute.internal    Ready    worker   15m   v1.14.6+c07e432da
ip-10-0-166-12.us-east-2.compute.internal    Ready    worker   16m   v1.14.6+c07e432da
ip-10-0-173-34.us-east-2.compute.internal    Ready    master   21m   v1.14.6+c07e432da
```

The Machines and MachineSets exist in the *openshift-machine-api* namespace. Each worker machine set is associated with a different availability zone within the AWS region. The installer automatically load balances workers across availability zones.

```
$ oc get machinesets -n openshift-machine-api
NAME                                     DESIRED   CURRENT   READY   AVAILABLE   AGE
openshift-blog-txxtf-worker-us-east-2a   1         1         1       1           22m
openshift-blog-txxtf-worker-us-east-2b   1         1         1       1           22m
openshift-blog-txxtf-worker-us-east-2c   1         1         1       1           22m
```

Right now there is only one worker machine per machine set, though a machine set could be scaled to add a node in a particular region and zone.

```
$ oc get machines -n openshift-machine-api | grep worker
openshift-blog-txxtf-worker-us-east-2a-8grnb   running   m4.large    us-east-2   us-east-2a   51m
openshift-blog-txxtf-worker-us-east-2b-vw4ph   running   m4.large    us-east-2   us-east-2b   51m
openshift-blog-txxtf-worker-us-east-2c-qpd4q   running   m4.large    us-east-2   us-east-2c   51m
```

Make a copy of one of the existing worker MachineSet definitions and output the result to a JSON file. This will be the basis for our GPU-enabled worker machine set definition.

```
$ oc get machineset openshift-blog-txxtf-worker-us-east-2a -n openshift-machine-api -o json > openshift-blog-txxtf-gpu-us-east-2a.json
```

Notice that we are replacing “worker” with “gpu” in the file name. This will be the name of our new MachineSet.

Edit the JSON file. Make the following changes to the new MachineSet definition:

Change the instance type of the new MachineSet definition to p3, which includes an NVIDIA Tesla V100 GPU. Read more about AWS P3 instance types: https://aws.amazon.com/ec2/instance-types/#Accelerated_Computing

```
$ jq .spec.template.spec.providerSpec.value.instanceType openshift-blog-txxtf-gpu-us-east-2a.json
"p3.2xlarge"
```

Change the name and self link to a unique name that identifies the new MachineSet. Then delete the status section from the definition.

A diff of the original worker definition and the new GPU-enabled node definition looks like this:

```
$ oc -n openshift-machine-api get machineset openshift-blog-txxtf-worker-us-east-2a -o json | diff openshift-blog-txxtf-gpu-us-east-2a.json -
10c10
<         "name": "openshift-blog-txxtf-gpu-us-east-2a",
---
>         "name": "openshift-blog-txxtf-worker-us-east-2a",
13c13
<         "selfLink": "/apis/machine.openshift.io/v1beta1/namespaces/openshift-machine-api/machinesets/openshift-blog-txxtf-gpu-us-east-2a",
---
>         "selfLink": "/apis/machine.openshift.io/v1beta1/namespaces/openshift-machine-api/machinesets/openshift-blog-txxtf-worker-us-east-2a",
21c21
<                 "machine.openshift.io/cluster-api-machineset": "openshift-blog-txxtf-gpu-us-east-2a"
---
>                 "machine.openshift.io/cluster-api-machineset": "openshift-blog-txxtf-worker-us-east-2a"
31c31
<                     "machine.openshift.io/cluster-api-machineset": "openshift-blog-txxtf-gpu-us-east-2a"
---
>                     "machine.openshift.io/cluster-api-machineset": "openshift-blog-txxtf-worker-us-east-2a"
60c60
<                         "instanceType": "p3.2xlarge",
---
>                         "instanceType": "m4.large",
104a105,111
>     },
>     "status": {
>         "availableReplicas": 1,
>         "fullyLabeledReplicas": 1,
>         "observedGeneration": 1,
>         "readyReplicas": 1,
>         "replicas": 1
```


Create the new MachineSet from the definition.

```
$ oc create -f openshift-blog-txxtf-gpu-us-east-2a.json
machineset.machine.openshift.io/openshift-blog-txxtf-gpu-us-east-2a created
```

View the new MachineSet.

```
$ oc -n openshift-machine-api get machinesets | grep gpu
openshift-blog-txxtf-gpu-us-east-2a      1         1         1       1           4m21s
```

The MachineSet replica count is set to “1” so a new Machine object is created automatically. View the new Machine object.

```
$ oc -n openshift-machine-api get machines | grep gpu
openshift-blog-txxtf-gpu-us-east-2a-rd665      running   p3.2xlarge   us-east-2   us-east-2a   4m36s
```

Eventually a node will come up based on the new definition. Find the node name.

```
$ oc -n openshift-machine-api get machines | grep gpu
openshift-blog-txxtf-gpu-us-east-2a-rd665      running   p3.2xlarge   us-east-2   us-east-2a   5m8s
```

View the metadata associated with the new node, including its labels. You can see the instance-type, operating system, zone, region, and hostname.

```
$ oc get node ip-10-0-132-138.us-east-2.compute.internal -o json | jq .metadata.labels
{
  "beta.kubernetes.io/arch": "amd64",
  "beta.kubernetes.io/instance-type": "p3.2xlarge",
  "beta.kubernetes.io/os": "linux",
  "failure-domain.beta.kubernetes.io/region": "us-east-2",
  "failure-domain.beta.kubernetes.io/zone": "us-east-2a",
  "kubernetes.io/arch": "amd64",
  "kubernetes.io/hostname": "ip-10-0-132-138",
  "kubernetes.io/os": "linux",
  "node-role.kubernetes.io/worker": "",
  "node.openshift.io/os_id": "rhcos"
}
```

Note that there is no need to specify a namespace for the node. The node definition is cluster scoped.

## Deploy the Node Feature Discovery Operator

After the GPU-enabled node is created, it’s time to discover the GPU enabled node so it can be scheduled. The first step in this process is to install the Node Feature Discovery (NFD) operator. 

The NFD operator identifies hardware device features in nodes. It solves the general problem of identifying and cataloging hardware resources in the infrastructure nodes so they can be made available to OpenShift. 

Install the Node Feature Discovery operator from OperatorHub in the OpenShift Container Platform console.

<kbd><img width="600" border="1px" src="https://github.com/jliberma/ocp4-gpu-aws/blob/master/md/images/aws1.png" /></kbd>

Once the NFD operator is installed into OperatorHub, select **Node Feature Discovery** from the installed operators list and select **Create instance**. This will install the *openshift-nfd* operator into the *openshift-operators* namespace.

<kbd><img width="600" src="https://github.com/jliberma/ocp4-gpu-aws/blob/master/md/images/aws2.png" /></kbd>

Verify the operator is installed and running.

```
$ oc get pods -n openshift-operators
NAME                           READY   STATUS    RESTARTS   AGE
nfd-operator-fd55688bd-4rrkq   1/1     Running   0          18m
```

Next, browse to the installed operator in the console. Select **Create Node Feature Discovery**. 

<kbd><img width="600" src="https://github.com/jliberma/ocp4-gpu-aws/blob/master/md/images/aws3.png" /></kbd>

Select **Create** to build a NFD Custom Resource. This will create NFD pods in the *openshift-nfd* namespace that poll the OpenShift nodes for hardware resources and catalogue them.

<kbd><img width="400" src="https://github.com/jliberma/ocp4-gpu-aws/blob/master/md/images/aws4.png" /></kbd>

After a successful build, verify that a NFD pod is running on each nodes.

```
$ oc get pods -n openshift-nfd
NAME               READY   STATUS    RESTARTS   AGE
nfd-master-mc99f   1/1     Running   0          51s
nfd-master-t7rrl   1/1     Running   0          51s
nfd-master-w9pgx   1/1     Running   0          51s
nfd-worker-5wwnw   1/1     Running   2          51s
nfd-worker-h2p2p   1/1     Running   2          51s
nfd-worker-n99l2   1/1     Running   2          51s
nfd-worker-xmmqx   1/1     Running   2          51s
```

The NFD operator uses vendor PCI IDs to identify hardware in a node. NVIDIA uses the PCI ID 10de. View the NVIDIA GPU discovered by the NFD operator.

```
$ oc describe node ip-10-0-132-138.us-east-2.compute.internal | egrep 'Roles|pci'
Roles:              worker
                    feature.node.kubernetes.io/pci-1013.present=true
                    feature.node.kubernetes.io/pci-10de.present=true
                    feature.node.kubernetes.io/pci-1d0f.present=true
```

“10DE” is the PCI vendor identification code for NVIDIA. So the NFD operator correctly identified the node from our GPU-enabled MachineSet.

## Conclusion

And that’s it! The Machine API lets us define, template, and scale nodes as easily as pods in ReplicaSets. We used the worker MachineSet definition as a template to create a GPU-enabled MachineSet definition with a different AWS instanceType. After we built a new node from this definition, we installed the Node Feature Discovery operator from OperatorHub. It detected the GPU and labeled the node so the GPU can be exposed to OpenShift’s scheduler. Taken together this is a great example of the power and simplicity of full stack automation in OpenShift Container Platform 4.2.

Subsequent blog posts will describe the process for loading GPU drivers and running jobs. The approaches differ slightly depending on whether the GPU drivers and libraries are installed directly to the host or dep;oyed via a pod daemon set.


## Resources
1. AWS Adds Nvidia GPUs: [https://aws.amazon.com/blogs/aws/new-amazon-ec2-instances-with-up-to-8-nvidia-tesla-v100-gpus-p3/]
2. Accelerated Computing with Nvidia GPU on OpenShift: [https://docs.nvidia.com/datacenter/kubernetes/openshift-on-gpu-install-guide/index.html]
3. OpenShift 4 Architecture: [https://access.redhat.com/documentation/en-us/openshift_container_platform/4.1/html/architecture/index]

