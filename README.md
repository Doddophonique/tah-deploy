# Terraform-Ansible-Helm Deployer
[![Super-Linter](https://github.com/doddophonique/tah-deploy/actions/workflows/super-linter.yml/badge.svg)](https://github.com/marketplace/actions/super-linter)
## Usage
From the `terraform/` folder:
```
$ terraform init
$ terraform plan
$ terraform apply
```

## Decisions and goals
The `terraform-provider-libvirt` has been chosen over Vagrant to deploy the VMs as a way to simplify the structure of the project. The choice over a cloud provider such as AWS or GCP has been done to not incur into billing cost during troubleshooting and deployments.
### Terraform script
The Terraform script roughly follows these steps:
  1. Deploy 3 VMs (one master and two workers) with:
     - 2 vCPUs;
     - 2GB vRAM;
     - 20GB of disk space;
     - Ubuntu 24.04 LTS;
     - An Ansible user.
  2. Call an Ansible Playbook that:
     1. Configures the master node and installs Kubernetes;
     2. Configures the network for the Kubernetes cluster;
     3. Configures the worker nodes and installs Kubernetes.
  3. Create the `kiratech-test` namespace;
  4. Run the CIS Kubernetes benchmark;
  5. Copy the helm folder to the master node and install helm.
### Next steps	
The script currently lacks:
  - [ ] Capability of deploying an Helm application;
  - [ ] Usage of Terraform outputs to populate Ansible files;

### CIS Kubernetes Benchmark
The CIS Benchamrk is one of (if not the) most popular benchmarks publicly available, and also has a simple way to implement it in a deployment pipeline using the [kube-bench](https://github.com/aquasecurity/kube-bench) implementation.

## Linting
The project uses Github Actions as a CI tool, running [super-linter](https://github.com/super-linter/super-linter) on the entire codebase.
