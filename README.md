# dinghy

Docker on OS X with batteries included, aimed at making a more pleasant local development experience.
Runs on top of [docker-machine](https://github.com/docker/machine).

  * Faster volume sharing using NFS rather than built-in virtualbox/vmware file shares. A medium-sized Rails app boots in 5 seconds, rather than 30 seconds using vmware file sharing, or 90 seconds using virtualbox file sharing.
  * Filesystem events work on mounted volumes. Edit files on your host, and see guard/webpack/etc pick up the changes immediately.
  * Easy access to running containers using built-in DNS and HTTP proxy.

Eventually `docker-machine` may have a rich enough plugin system that dinghy can
just become a plugin to `docker-machine`. For now, dinghy runs as a wrapper
around `docker-machine`, shelling out to create the VM and using `launchd` to
start the various services such as NFS and DNS.

## install

First the prerequisites:

1. OS X Yosemite (10.10) (Mavericks has a known issue, see [#6](https://github.com/codekitchen/dinghy/issues/6))
1. [Homebrew](https://github.com/Homebrew/homebrew)
1. Either [VirtualBox](https://www.virtualbox.org) or [VMware Fusion](http://www.vmware.com/products/fusion). If using VirtualBox, version 5.0+ is strongly recommended.

Then:

    $ brew install --HEAD https://github.com/codekitchen/dinghy/raw/machine/dinghy.rb

This will install the `docker` client and `docker-machine` using Homebrew, as well.

You can specify provider (virtualbox or vmware), memory and CPU options when creating the VM. See available options:

    $ dinghy help create

Then create the VM and start services with:

    $ dinghy create --provider virtualbox

Once the VM is up, you'll get instructions to add some Docker-related
environment variables, so that your Docker client can contact the Docker
server inside the VM. I'd suggest adding these to your .bashrc or
equivalent.

Sanity check!

    $ docker run -it redis

## DNS

Dinghy starts a DNS container via Docker, which resolves \*.docker to the Dinghy VM. This uses the easily-configurable [dnsdock](https://github.com/tonistiigi/dnsdock) container.

It also sets up a network route on your host machine so that all \*.docker DNS entries get forwarded through to this nameserver.

To set a hostname for a container, just specify the `DNSDOCK_ALIAS` environment variable, either with the -e option to docker or the environment hash in docker-compose. For instance setting DNSDOCK_ALIAS=myrailsapp.docker will make the container's exposed port available at http://myrailsapp.docker/.

```yaml
web:
  build: .
  ports:
    - "3000:3000"
  environment:
    DNSDOCK_ALIAS: myrailsapp.docker
```

## a note on NFS sharing

Dinghy shares your home directory (`/Users/<you>`) over NFS, using a
private network interface between your host machine and the Dinghy
Vagrant VM. This sharing is done using a separate NFS daemon, not the
system NFS daemon.

Be aware that there isn't a lot of security around NFSv3 file shares.
We've tried to lock things down as much as possible (this NFS daemon
doesn't even listen on other interfaces, for example).

## upgrading

To update Dinghy itself, run:

    $ brew reinstall --HEAD https://github.com/codekitchen/dinghy/raw/machine/dinghy.rb

To update the Docker VM, run:

    $ dinghy upgrade

This will run `docker-machine upgrade` and then restart the dinghy services.

### prereleases

You can install Dinghy's master branch with:

    $ brew reinstall --HEAD https://github.com/codekitchen/dinghy/raw/master/dinghy.rb

This branch may be less stable, so this isn't recommended in general.

## built on

 - https://github.com/docker/machine
 - https://github.com/markusn/unfs3
 - https://github.com/Homebrew/homebrew
 - http://www.thekelleys.org.uk/dnsmasq/doc.html
 - https://github.com/jwilder/nginx-proxy
