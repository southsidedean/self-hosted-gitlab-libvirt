# What Hardware Do You Need?

[GitLab: Installation requirements](https://docs.gitlab.com/install/requirements/)

My "lab in a box" runs on an old Dell workstation with plenty of memory, but you don't need that exact machine.  Here's what to plan for.

## GitLab

| Resource | What GitLab asks for |
|---|---|
| CPU | 8 vCPUs |
| Memory | 16GB (*a single machine can get by with 8GB if it has to*) |
| Storage | 40GB for GitLab itself, 5-12GB for PostgreSQL, plus room for your repositories |

GitLab recommends SSD storage, and says to avoid network file systems like NFS.  It also recommends turning off swap where you can, since swap can really slow things down under load.

## Your Job VMs

Each CI/CD job gets its own virtual machine, on top of what GitLab uses.  With the settings in this repository, that's:

- 2 vCPUs and 2GB of RAM per job (`opt/libvirt-driver/prepare.sh`)
- An 8GB base image (`runner-builder.sh`), plus a small disk for each job while it runs

Add your other workloads on top of that.  If you plan to run Terraform projects that create VMs of their own, leave them plenty of room.

## Virtualization Support

Your CPU needs hardware virtualization, and it needs to be turned on in the BIOS/UEFI.  Let's check:
```bash
lscpu | grep Virtualization
```

You should see `VT-x` or `AMD-V`.

***If you're testing all of this inside a virtual machine, you'll need nested virtualization turned on, so your job VMs have somewhere to run.***
