# main.tf

# Launch the Google Compute Engine instances # and install microk8s.

# Local variables
#
# instances - map - as "flattend" map of the instanceInfo variable to make it
# easier to iterate over them with for_each in the microk8s instance Terraform
# resource.   Storing the instanceKey from the instanceInfo map and a unique
# index for each of the instanceCount copies of each instanceInfo map
# provides a way to uniquely distinguish all of the instanes which will help
# with Terraform state when entries are added or removed from the
# instanceInfo map.
#
# number_of_instances - number - the number of instances in the instances map.
#
# gcloudLabelFilter - string - the filter to use on gcloud to delect the
# instances with a given label.
#
# gcloudFormatNamesOnly - string - a gcloud output formatter to display only
# the instance names, one per line for each instance displayed.
#
# sshGitURL = the URL for doing ssh commits to Cloud Source Repositories.

locals {
  instances = flatten([
    for instanceKey, instance in var.instanceInfo : [
      for index in range(instance.instanceCount) : {
        name = instance.name
        zone = instance.zone
        imageProject = instance.imageProject
        imageFamily = instance.imageFamily
        machineType = instance.machineType
        network = instance.network
        instanceIndex = index
        instanceKey = instanceKey
      }
    ]
  ])

  number_of_instances = length(local.instances)

  gcloudLabelFilter = "labels.cloud-init-done=${var.suffix}"
  gcloudFormatNamesOnly = "csv [no-heading] (name)"
}

# microk8s_instances - Create and initialize the microk8s isntances.
# Cloud-init is uesd to perform the initialization.  Here are the
# main steps:
#
# (1) Add a random suffix.
# (2) Iterate over the instanceInfo map and launch the instances.
# (3) Use cloud-init to initialize the instances.
# 
#     (a) Use PAM (programmable authentication module) to
#         add all users to the microk8s group after logging on.
#     (b) Store the private service account key for cluster registration in
#         /usr/local/etc/anthos/cluster-reg-key.json
#
#     (c) Create /usr/local/etc/anthos/110-register-cluster to register the
#         cluster with the Anthos/GKE hub.
#     (d) Create /usr/local/etc/anthos/120-create-ksa to create the Kubernetes
#         Service Account (KSA) for granting the console user access to
#         the cluster after logging into it.
#     (e) Create /usr/local/etc/anthos/130-get-ksa-bearer-token to display
#         the KSA bearer token for logging into the cluster.
#
#     (f) Create /usr/local/etc/anthos/210-register-acm-private-key to
#         Store the private key into the cluster.
#     (g) Create /usr/local/etc/anthos/220-config-acm to
#         apply the initial configuration to the cluster.
#     (h) Create /usr/local/etc/anthos/230-check-acm-status to poll
#         the ACM status on the cluster.
#
#     (i) Create /usr/local/etc/anthos/910-unregister-cluster to
#         deregister the cluster.
#     
#     (j) Set a label on the instance at the end of cloud-init which will
#         be checked by the nill_resource below to see if all instances
#         have been properly initialized.



resource "google_compute_instance" "microk8s_instances" {
  for_each = {
    for inst in local.instances :
      format("%s-%02d", inst.instanceKey, inst.instanceIndex + 1) => inst
  }
      
  name         = "${each.key}-${var.suffix}"
  machine_type = each.value.machineType
  zone         = each.value.zone

  boot_disk {
    initialize_params {
      image = join("", [
        "projects/",
        each.value.imageProject,
        "/global/images/family/",
        each.value.imageFamily
      ])
    }
  }

  network_interface {
    network = each.value.network

    access_config {
      // Ephemeral IP
    }
  }

  service_account {
    email = var.SAemail
    scopes = [
      "cloud-platform"
    ]
  }

  metadata = {
    user-data = <<EOF
#cloud-config

# Generate the files listed below. Most of the files have comments within
# them.  The following information is provided for additional context.
#
# /etc/security.conf and /etc/pam.d/ssh - These files are updated so that
# all users who log in are placed in the microk8s.

write_files:
- path: /etc/bash.bashrc
  content: |
    # set up Kubernetes

    if [ ! -d ~/.kube ]
    then
      echo Creating ~/.kube/config...
      mkdir -p ~/.kube
      microk8s config > ~/.kube/config
    fi

    # Turn of syntax highlighting - a personal preference.

    if [ ! -f ~/.vimrc ]
    then
      echo Creating ~/.vimrc...
      echo "syntax off" > ~/.vimrc
    fi

    echo All Anthos files are in /usr/local/etc/anthos.
    export CLUSTER_CONTEXT=`kubectl config current-context`
    export KUBECONFIG_PATH=~/.kube/config
    export SA_KEY_PATH=/usr/local/etc/anthos/cluster-reg-key.json
  append: true

- path: /etc/security/group.conf
  content: |
    *;*;*;Al;microk8s
  append: true

- path: /etc/pam.d/sshd
  content: |
    auth       optional     pam_group.so
  append: true

- path: /usr/local/etc/anthos/cluster-reg-key.json
  content: ${var.SAprivateKey}
  encoding: base64
  permissions: "0664"

- path: /usr/local/etc/anthos/acm-private-key.pem
  content: ${var.CMprivateKey}
  encoding: base64
  permissions: "0664"

- path: /usr/local/etc/anthos/config-management.yaml
  content: |
    # config-management.yaml

    apiVersion: configmanagement.gke.io/v1
    kind: ConfigManagement
    metadata:
      name: config-management
    spec:
      git:
        syncRepo: "INSERT_SSH_CLONE_URL_HERE"
        syncBranch: ${var.gitBranch}
        secretType: ssh
  permissions: "0664"

- path: /usr/local/etc/anthos/110-register-cluster
  content: |
    #!/bin/sh

    # register-cluster
    #
    # Register the cluster using the service account private key.

    echo Registering cluster to hub...
    gcloud container hub memberships register `hostname` \
       --context="$CLUSTER_CONTEXT" \
       --service-account-key-file=$SA_KEY_PATH \
       --kubeconfig=$KUBECONFIG_PATH \
       --project=${var.project}
  permissions: "0755"

- path: /usr/local/etc/anthos/120-create-ksa
  content: |
    #!/bin/sh

    # create-ksa
    #
    # Create the Kubernetes Service Account (KSA) that will be used when
    # logging into the cluster from the cluster registration console page.
    #
    # Details:
    #
    # (1) Create the Kubernetes Service Account.
    # (2) Define the cloud-console-reader role.
    # (3) Bind the cloud-console-reader role to the KSA.
    # (4) Bind the view role to the KSA

    KSA_NAME=anthos-ksa
    echo Creating Kubernetes service account $KSA_NAME...
    kubectl create serviceaccount $KSA_NAME

    echo Creating console-reader-role cluster role...
    kubectl apply -f - <<NESTEDEOF
    kind: ClusterRole
    apiVersion: rbac.authorization.k8s.io/v1
    metadata:
      name: cloud-console-reader
    rules:
    - apiGroups: [""]
      resources: ["nodes", "persistentvolumes"]
      verbs: ["get", "list", "watch"]
    - apiGroups: ["storage.k8s.io"]
      resources: ["storageclasses"]
      verbs: ["get", "list", "watch"]
    NESTEDEOF

    echo Binding console-reader-role cluster role to cluster $KSA_NAME...
    kubectl create clusterrolebinding cloud-console-reader-binding \
      --clusterrole cloud-console-reader --serviceaccount default:$KSA_NAME

    echo Binding view cluster role to cluster $KSA_NAME...
    kubectl create clusterrolebinding view-binding \
      --clusterrole view --serviceaccount default:$KSA_NAME
  permissions: "0755"

- path: /usr/local/etc/anthos/130-get-ksa-bearer-token
  content: |
    #!/bin/sh

    # get-ksa-bearer-token
    #
    # Display the bearer token of the Kubernetes Service Account.  This is
    # needed to login to the cluster from the cluster registration page.

    KSA_NAME=anthos-ksa
    JSON_PATH='{$.secrets[0].name}'
    SECRET_NAME=$(kubectl get serviceaccount $KSA_NAME -o jsonpath="$JSON_PATH")

    JSON_PATH='{$.data.token}'
    TOKEN=$(
      kubectl get secret "$SECRET_NAME" -o jsonpath="$JSON_PATH" | 
      base64 --decode 
    )

    echo === The cluster token starts below this line. ===
    echo $TOKEN
    echo === The cluster token ends above this line. ===
    echo
    echo Use this token to login to the cluster from the Google Cloud console.
  permissions: "0755"

- path: /usr/local/etc/anthos/210-register-acm-private-key
  content: |
    #!/bin/sh

    # register-acm-private-key
    #
    # Register the private key to the Anthos Configuration Management
    # repository so ACM can fetch deployments from the repository and
    # deploy them to the cluster.

    kubectl create ns config-management-system && \
    kubectl create secret generic git-creds \
      --namespace=config-management-system \
      --from-file=ssh=/usr/local/etc/anthos/acm-private-key.pem
  permissions: "0755"

- path: /usr/local/etc/anthos/220-config-acm
  content: |
    #/bin/sh

    # config-acm
    #
    # Apply initial configuration for Anthos Confifuration Management.

    gcloud alpha container hub config-management apply \
      --membership=`hostname` \
      --config=./config-management.yaml \
      --project=${var.project}
  permissions: "0755"

- path: /usr/local/etc/anthos/230-check-acm-status
  content: |
    #/bin/sh

    # check-acm-status
    #
    # Check the status of ACM to see if the cluster is synced with
    # the Anthos Configuration Management repository.

    gcloud alpha container hub config-management status \
      --project=jslevine-anthos
  permissions: "0755"

- path: /usr/local/etc/anthos/910-unregister-cluster
  content: |
    #!/bin/sh

    # unregister-cluster
    #
    # Unregister the cluster

    echo Unregistering cluster from hub...
    gcloud container hub memberships unregister `hostname` \
       --context="$CLUSTER_CONTEXT" \
       --kubeconfig=$KUBECONFIG_PATH \
       --project=${var.project}
  permissions: "0755"

snap:
  commands:
    00: snap install microk8s --classic --channel=${var.microk8sRelease}
    05: snap install kubectl --classic --channel=${var.microk8sRelease}

# Perform the commands below later in the boot cycle after all software
# has been installed and all files have been written.
#
# (1) Change the permissions of /usr/local/etc/anthos to 777 so that
#     whoever is logged in can set up Anthos Configuration Management.
#     The ACM sync process needs to be able to write into the directory
#     /usr/local/etc/anthos but we don't know who will be logging in
#     and what group the user will receive when logging in.
#
# (2) Wait until microk8s is fully up.
#
# (3) Initialize optional microk8s components.
#
# (4) Add a label to the instance to indicate that cloud-init has finished.
#     While there may be additional steps in cloud-init, enough should be
#     done at this point (snaps have completed, etc.) to consider the
#     instance initialized.

runcmd:
- chmod 775 /usr/local/etc/anthos
- chgrp -R ubuntu /usr/local/etc/anthos
- microk8s status --wait-ready
- microk8s enable dashboard dns:169.254.169.254 storage
- - gcloud
  - compute 
  - instances 
  - "add-labels"
  - "${each.key}-${var.suffix}"
  - "--zone"
  - "${each.value.zone}"
  - "--labels=${var.initCompletedLabel}=${var.suffix}"
EOF
  }
}

# This null_resource doesn't generate any Google Cloud resources, but is used
# within Terraform to keep track of how many instances have completed their
# initialization with cloud-init.  This script is needed because Google Cloud
# considers the instance to be "ready" shortly after it's launched.   This
# means that cloud-init may not have yet completed it's initialization.
#
# When each instance is created, the last step of the cloud-init script
# defined above sets a label whose key is defined in var.initCompleted label
# and whose value is the random string generated by Terraform.
#
# The null_resource lists all of the instances that have this label key/value
# defined.  If the number of instances with the key/value label equals the
# number of instances generated by Terraform, then all the instances have been
# initialized.
#
# Note that a trigger is defined to cause the null_resource to be
# regenerated if there is any chance in the instance_id value (either through
# instance creations or deletion.  It does this by joining all the
# instance_id values into a string. If the string changes, the null_resource
# must be recreated and all instances rechedked.
#
# Lastly, this instance runs on the *local* machine, the run on which
# Terraform is running, not the instances themselves.  This removes the need
# to ssh into the instances.

resource "null_resource" "wait_for_instances" {
  triggers = {
    instance_ids = join(
      ",",
      [ for i in google_compute_instance.microk8s_instances : i.instance_id ]
    )
  }

  provisioner "local-exec" {
    command = <<EOF
LABELED_INSTANCES=0
while [ "$LABELED_INSTANCES" -ne "${local.number_of_instances}" ]
do
  sleep 10
  LABELED_INSTANCES=$( \
    gcloud compute instances list \
      --filter="${local.gcloudLabelFilter}" \
      --format="${local.gcloudFormatNamesOnly}" | wc -l )
    echo $LABELED_INSTANCES / \
      ${local.number_of_instances} \
      instances initialized
done
EOF
  }
}
