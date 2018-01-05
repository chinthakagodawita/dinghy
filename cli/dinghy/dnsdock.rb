require 'stringio'
require 'tempfile'

require 'dinghy/machine'

class Dnsdock
  CONTAINER_NAME = "dinghy_dnsdock"
  CONTAINER_IP = "172.17.0.1"
  DOCKER_SUBNET = "172.17.0.0/16"
  RESOLVER_DIR = Pathname("/etc/resolver")

  attr_reader :machine, :resolver_file, :dinghy_domain

  def initialize(machine, dinghy_domain)
    @machine = machine
    self.dinghy_domain = dinghy_domain || "docker"
  end

  def dinghy_domain=(dinghy_domain)
    @dinghy_domain = dinghy_domain
    @resolver_file = RESOLVER_DIR.join(@dinghy_domain)
  end

  def up
    puts "Starting the DNS nameserver"
    System.capture_output do
      docker.system("rm", "-fv", CONTAINER_NAME)
    end
    docker.system("run", "-d",
      "-v", "/var/run/docker.sock:/var/run/docker.sock",
      "--name", CONTAINER_NAME,
      "-p", "#{CONTAINER_IP}:53:53/udp",
      "aacebedo/dnsdock:latest-amd64",
      "--domain=\".#{@dinghy_domain}\"",
      "--ttl=0")
    unless resolver_configured?
      configure_resolver!
    end
    route_add!
  end

  def halt
    route_remove!
  end

  def status
    return "stopped" if !machine.running?

    output, _ = System.capture_output do
      docker.system("inspect", "-f", "{{ .State.Running }}", CONTAINER_NAME)
    end

    if output.strip == "true"
      "running"
    else
      "stopped"
    end
  end

  def configure_resolver!
    puts "setting up DNS resolution, this will require sudo"
    unless RESOLVER_DIR.directory?
      system!("creating #{RESOLVER_DIR}", "sudo", "mkdir", "-p", RESOLVER_DIR)
    end
    Tempfile.open('dinghy-dnsdock') do |f|
      f.write(resolver_contents)
      f.close
      system!("creating #{@resolver_file}", "sudo", "cp", f.path, @resolver_file)
      system!("creating #{@resolver_file}", "sudo", "chmod", "644", @resolver_file)
    end
  end

  def resolver_configured?
    @resolver_file.exist? && File.read(@resolver_file) == resolver_contents
  end

  def resolver_contents; <<-EOS.gsub(/^    /, '')
    # Generated by dinghy
    nameserver #{CONTAINER_IP}
    EOS
  end

  def route_add!
    System.capture_output do
      system!("creating route", "sudo", "route", "-n", "add", DOCKER_SUBNET, machine.vm_ip)
    end
    flush_dns_cache!
  end

  def route_remove!
    System.capture_output do
      system!("removing route", "sudo", "route", "-n", "delete", DOCKER_SUBNET)
    end
    flush_dns_cache!
  end

  def flush_dns_cache!
    os_version = `sw_vers -productVersion`.strip!.split('.')
    if os_version[1] == "10" && os_version[2] && os_version[2].to_i < 4
      system!("flushing discoveryutil MDNS cache", "sudo", "discoveryutil", "mdnsflushcache")
    else
      system!("restarting mDNSResponder", "sudo", "killall", "mDNSResponder")
    end
  end

  def system!(step, *args)
    system(*args.map(&:to_s)) || raise("Error with the DNS nameserver during #{step}")
  end

  private

  def docker
    @docker ||= Docker.new(machine)
  end
end
