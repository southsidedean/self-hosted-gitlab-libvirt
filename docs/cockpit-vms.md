# Managing VMs in Cockpit

[Cockpit: Applications](https://cockpit-project.org/applications)

Sometimes you want to treat your "lab in the box" as an appliance and skip the CLI, right?  Cockpit can also create, run and manage your virtual machines.  It only takes one more package.

Install `cockpit-machines`:
```bash
sudo apt-get update ; sudo apt-get install -y cockpit-machines
```

Log in to Cockpit at `https://lab-host.example.com:8090`, using your own host name and the port you picked when you installed Cockpit.  If you don't see your VMs, you might need to turn on administrative access in Cockpit.

Select **Virtual Machines** in the menu.  You should see your virtual machines, and if a CI/CD job is running, you'll see its job VM there too.

***Look, but don't touch, when it comes to job VMs.  The runner creates and deletes those on its own, so deleting one yourself will fail the job that's using it.***
