# -*- mode: ruby -*-
# vi: set ft=ruby :

VAGRANTFILE_API_VERSION = "2"
UBUNTU_IMAGE = "ubuntu:20.04"
PRIMARY_DOMAIN = "serivicios.local"
IPV6_PREFIX = "fd00:100:100"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  # Use Docker bind mount for /vagrant so scripts are immediately available inside containers
  # Disable the global synced_folder to avoid provider validation errors for Docker
  config.vm.synced_folder ".", "/vagrant", disabled: true

  # DNS Primario
  config.vm.define "dns-primary" do |dns_primary|
    dns_primary.vm.provider "docker" do |d|
      d.image = UBUNTU_IMAGE
      d.name = "dns-primary"
      d.has_ssh = false
      d.remains_running = true
      # Execute provisioning script inside container and keep it running
      d.cmd = ["/bin/bash", "-lc", "chmod +x /vagrant/scripts/*.sh || true && /vagrant/scripts/bootstrap.sh #{IPV6_PREFIX}::a ns1.#{PRIMARY_DOMAIN} && /vagrant/scripts/dns-primary-setup.sh && tail -f /dev/null"]
      # Mount project directory into container at /vagrant
      d.volumes = ["#{File.expand_path('.') }:/vagrant"]
      d.create_args = [
        "--network", "bridge",
        "--hostname", "ns1.#{PRIMARY_DOMAIN}"
      ]
    end
    dns_primary.vm.hostname = "ns1.#{PRIMARY_DOMAIN}"
    # Provisioning executed inside container via d.cmd (no SSH)
  end

  # DNS Secundario
  config.vm.define "dns-secondary" do |dns_secondary|
    dns_secondary.vm.provider "docker" do |d|
      d.image = UBUNTU_IMAGE
      d.name = "dns-secondary"
      d.has_ssh = false
      d.remains_running = true
      d.cmd = ["/bin/bash", "-lc", "chmod +x /vagrant/scripts/*.sh || true && /vagrant/scripts/bootstrap.sh #{IPV6_PREFIX}::b ns2.#{PRIMARY_DOMAIN} && /vagrant/scripts/dns-secondary-setup.sh && tail -f /dev/null"]
      d.volumes = ["#{File.expand_path('.') }:/vagrant"]
      d.create_args = [
        "--network", "bridge",
        "--hostname", "ns2.#{PRIMARY_DOMAIN}"
      ]
    end
    dns_secondary.vm.hostname = "ns2.#{PRIMARY_DOMAIN}"
    # Provisioning executed inside container via d.cmd (no SSH)
  end

  # DHCP
  config.vm.define "dhcp" do |dhcp_server|
    dhcp_server.vm.provider "docker" do |d|
      d.image = UBUNTU_IMAGE
      d.name = "dhcp"
      d.has_ssh = false
      d.remains_running = true
      d.cmd = ["/bin/bash", "-lc", "chmod +x /vagrant/scripts/*.sh || true && /vagrant/scripts/bootstrap.sh #{IPV6_PREFIX}::c dhcp.#{PRIMARY_DOMAIN} && /vagrant/scripts/dhcp-setup.sh && tail -f /dev/null"]
      d.volumes = ["#{File.expand_path('.') }:/vagrant"]
      d.create_args = [
        "--network", "bridge",
        "--hostname", "dhcp.#{PRIMARY_DOMAIN}",
        "--cap-add", "NET_ADMIN",
        "--cap-add", "NET_RAW",
        "--sysctl", "net.ipv6.conf.all.disable_ipv6=0",
        "--sysctl", "net.ipv6.conf.default.disable_ipv6=0",
        "--sysctl", "net.ipv6.conf.lo.disable_ipv6=0",
        "--sysctl", "net.ipv6.conf.eth0.disable_ipv6=0"
      ]
    end
    dhcp_server.vm.hostname = "dhcp.#{PRIMARY_DOMAIN}"
    # Provisioning executed inside container via d.cmd (no SSH)
  end

  # Mail
  config.vm.define "mail" do |mail|
    mail.vm.provider "docker" do |d|
      d.image = UBUNTU_IMAGE
      d.name = "mail"
      d.has_ssh = false
      d.remains_running = true
      d.cmd = ["/bin/bash", "-lc", "chmod +x /vagrant/scripts/*.sh || true && /vagrant/scripts/bootstrap.sh #{IPV6_PREFIX}::20 mail.#{PRIMARY_DOMAIN} && /vagrant/scripts/mail-setup.sh && tail -f /dev/null"]
      d.volumes = ["#{File.expand_path('.') }:/vagrant"]
      d.create_args = [
        "--network", "bridge",
        "--hostname", "mail.#{PRIMARY_DOMAIN}"
      ]
    end
    mail.vm.hostname = "mail.#{PRIMARY_DOMAIN}"
    # Provisioning executed inside container via d.cmd (no SSH)
  end

  # Cliente 1
  config.vm.define "client1" do |client|
    client.vm.provider "docker" do |d|
      d.image = UBUNTU_IMAGE
      d.name = "client1"
      d.has_ssh = false
      d.remains_running = true
      d.cmd = ["/bin/bash", "-lc", "chmod +x /vagrant/scripts/*.sh || true && /vagrant/scripts/client-setup.sh && tail -f /dev/null"]
      d.volumes = ["#{File.expand_path('.') }:/vagrant"]
      d.create_args = [
        "--network", "bridge",
        "--hostname", "client1.#{PRIMARY_DOMAIN}"
      ]
    end
    client.vm.hostname = "client1.#{PRIMARY_DOMAIN}"
    client.vm.provision "shell", path: "scripts/client-setup.sh"
  end

  # Cliente 2
  config.vm.define "client2" do |client|
    client.vm.provider "docker" do |d|
      d.image = UBUNTU_IMAGE
      d.name = "client2"
      d.has_ssh = false
      d.remains_running = true
      d.cmd = ["/bin/bash", "-lc", "chmod +x /vagrant/scripts/*.sh || true && /vagrant/scripts/client-setup.sh && tail -f /dev/null"]
      d.volumes = ["#{File.expand_path('.') }:/vagrant"]
      d.create_args = [
        "--network", "bridge",
        "--hostname", "client2.#{PRIMARY_DOMAIN}"
      ]
    end
    client.vm.hostname = "client2.#{PRIMARY_DOMAIN}"
    client.vm.provision "shell", path: "scripts/client-setup.sh"
  end

  # Elimina triggers y net-setup innecesarios para Docker
end