# Using https://github.com/zloeber/k8s-lab-terraform-libvirt/blob/master/main.tf
# as a base
terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "0.8.0"
    }
    template = {
        source = "hashicorp/template"
        version = "2.2.0"
    }
  }
}

# Define local variables to use within the script
locals {
  masternodes = 1
  workernodes = 2
  subnet_node_prefix = "172.16.1"
}

# instance the provider
provider "libvirt" {
  uri = "qemu:///system"
}

# path.cwd is the filesystem path of the original working directory from where you ran Terraform before applying any -chdir argument.
resource libvirt_pool local {
  name = "ubuntu"
  type = "dir"
  path = "${path.cwd}/volume_pool"
}

resource libvirt_volume ubuntu2404_cloud {
  name   = "ubuntu24.04.qcow2"
  pool   = libvirt_pool.local.name
  source = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
  format = "qcow2"
}

resource libvirt_volume ubuntu2404_resized {
  name           = "ubuntu-volume-${count.index}"
  base_volume_id = libvirt_volume.ubuntu2404_cloud.id
  pool           = libvirt_pool.local.name
  size           = 21474836480
  count          = local.masternodes + local.workernodes
}


data template_file public_key {
  template = file("${path.module}/.local/.ssh/id_rsa.pub")
}

data template_file master_user_data {
  count = local.masternodes
  template = file("${path.module}/cloud_init.cfg")
  vars = {
    public_key = data.template_file.public_key.rendered
    hostname = "k8s-master-${count.index + 1}"
  }
}

data template_file worker_user_data {
  count = local.workernodes
  template = file("${path.module}/cloud_init.cfg")
  vars = {
    public_key = data.template_file.public_key.rendered
    hostname = "k8s-worker-${count.index + 1}"
  }
}

resource libvirt_cloudinit_disk masternodes {
  count = local.masternodes
  name = "cloudinit_master_resized_${count.index}.iso"
  pool = libvirt_pool.local.name
  user_data = data.template_file.master_user_data[count.index].rendered
}

resource libvirt_cloudinit_disk workernodes {
  count = local.workernodes
  name = "cloudinit_worker_resized_${count.index}.iso"
  pool = libvirt_pool.local.name
  user_data = data.template_file.worker_user_data[count.index].rendered
}

resource libvirt_network kube_node_network {
  name      = "kube_nodes"
  mode      = "nat"
  domain    = "k8s.local"
  autostart = true
  addresses = ["${local.subnet_node_prefix}.0/24"]
  dns {
    enabled = true
  }
}

resource libvirt_domain k8s_masters {
  count = local.masternodes
  name   = "k8s-master-${count.index+1}"
  memory = "4096"
  vcpu   = 2

  cloudinit = libvirt_cloudinit_disk.masternodes[count.index].id

  network_interface {
    network_id     = libvirt_network.kube_node_network.id
    hostname       = "k8s-master-${count.index+1}"
    addresses      = ["${local.subnet_node_prefix}.1${count.index+1}"]
    wait_for_lease = true
  }

  disk {
    volume_id = libvirt_volume.ubuntu2404_resized[count.index].id
  }

  console {
    type        = "pty"
    target_type = "serial"
    target_port = "0"
  }

  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }
}

resource libvirt_domain k8s_workers {
  count = local.workernodes
  name   = "k8s-worker-${count.index + 1}"
  memory = "2048"
  vcpu   = 2

  cloudinit = libvirt_cloudinit_disk.workernodes[count.index].id

  network_interface {
    network_id     = libvirt_network.kube_node_network.id
    hostname       = "k8s-worker-${count.index + 1}"
    addresses      = ["${local.subnet_node_prefix}.2${count.index + 1}"]
    wait_for_lease = true
  }

  disk {
    volume_id = libvirt_volume.ubuntu2404_resized[local.masternodes+count.index].id
  }

  console {
    type        = "pty"
    target_type = "serial"
    target_port = "0"
  }

  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }
}
