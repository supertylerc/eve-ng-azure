# UNMAINTAINED

This repo is being archived.  I haven't used EVE-NG in a public cloud in a
(very) long time.  Terraform things have probably changed.  Azure has likely
changed.  EVE-NG has definitely changed.  This in this repo may still work
or at least serve as inspiration.

# eve-ng-azure

This repository uses [Terraform](https://terraform.io) to manage an Azure
infrastructure and [Ansible](https://ansible.com) to manage the images and
configuration for an EVE-NG lab in a public cloud.

# Why?

Because cloud all the things, obviously.

## Why a Cloud Lab?

The largest system I have at home has 24G RAM, which doesn't offer much when
trying to run Junos, IOS-XR, or NX-OS topologies.

## Why Azure?

I already have experience with AWS and GCP.  I specifically have a decent bit
of experiencing running Terraform with GCP in production.  I wanted to learn
a little bit of something new during this process, so I chose Azure.  I could
have just stuck with AWS and learned Terraform + AWS as "something new," but
since I already know both of them independently, that just seemed like
cheating.

## Why Terraform?

As I mentioned earlier, I have some experience with it already.  I also wanted
the infrastructure to be easy to spin up and down and recreate as needed.
Finally, I wanted it to be somewhat portable so I could share with colleagues
if they were interested.

## Why Ansible?

Anyone who knows me knows I'm pretty down on Ansible.  However, I've always
said that it's good for the simple uses cases.  And this is exactly that:
a simple use case.  It is only going to be copying files, doing some package
installations, and a few other odds and ends.  For one server.

# Additional Notes

Packer could've been used for building a managed image, and then VMs could
have been built from the managed image.  However, this introduces additional
dependency considerations since Packer requires an Azure Resource Group to
build and publish an image, and Terraform is the thing that creates the ARG.
Terraform can't use Packer to build images (which seems odd, but oh well).
One could use a null resource provider and shell out to Packer and then use the
`depends_on` feature, but this seems overly complicated.  It would also require
either duplicating credentials between Terraform and Packer or passing them in
the `local-exec` provisioner, which again still seems messy.  All of that said,
though, if someone wants to submit a PR to implement an integration with Packer
and remove the relevant Ansible bits, I'm open to it as long as it's elegant
and easy to understand.

State is local.  I considered (very briefly) using an Azure-backed remote state
storage, but this again introduces dependencies managed outside of Terraform,
and the overall goal of this repository is to make things as simple as possible
(after someone has signed up for an Azure account and create a Principal
Service for authentication).  To use remote state storage, one would have to
manually create the relevant Blob Storage container or have a separate
Terraform workflow.  Again, this is counter to the goals of this project.
Finally, this project is largely intended for use by individuals and not teams
or groups.  However, if you find that you have a use case for remote storage,
I'd be open to a PR to implement it.  The implementation would have to be
opt-in.  It would not be a requirement to use Azure as the backend.

The Ansible playbook is pretty basic.  There is a lot of checking it doesn't
do but probably should (like making sure it's formatting the right disk).
Finally, portions of it are an adaptation of the EVE-NG Community Edition bash
script.  This was done because I found that the default script would break the
VM, and I didn't feel like shipping yet another script/flie.

# Terraform

This project uses Terraform and Azure.  If you're unfamiliar with either, then
you can learn a little bit about both in the
[Terraform Azure Tutorial](https://learn.hashicorp.com/terraform/azure/intro_az).
It is strongly recommended that you go through this tutorial if you have no
experience with Terraform; it won't take long.

## Authentication

While the tutorial above works, it uses personal credentials.  This project, on
the other hand, makes use of a service principal for authentication.  This is
similar to a Service Account in GCP.  To learn how to set this up, check the
[Terraform Tutorial on Authenticating with Service Principal Client Certificates](https://learn.hashicorp.com/terraform/azurerm/authentication-service-principal-client-certificate).

Once setup, you can place the key in this repository.  The `.gitignore` will
ignore all files that end in `.crt`, `.key`, `.csr`, and `.pfx`.

## Variables

This project has a few default variables defined in `terraform.tfvars`.  You
can override them either on the command line with manual invocations of
`terraform` or you can place those overrides in the `terraform/secrets.tfvars`
file (see below).  Those variables, their purposes, and their defaults are
listed below.

| Variable                | Default Value           | Purpose                                                                                                   |
|-------------------------|-------------------------|-----------------------------------------------------------------------------------------------------------|
| region                  | uswest2                 | Define region in which resources will be created                                                          |
| client_certificate_path | service-principal.pfx   | Path on your local disk where the Service Principal client certificate is located                         |
| vm_username             | eve                     | Username for the VM created                                                                               |
| vm_size                 | Standard_D2s_v3         | Azure VM size.  Note that this must be one of the types that support Nested Virtualization.               |
| ssh_pubkey              | ${file("./id_rsa.pub")} | The contents of your SSH public key                                                                       |
| disk_size               | 100                     | The size (in GB) of the extra disk for holding your images (mounted later at `/opt/unetlab/addons/qemu/`) |
| vm_ip                   | 10.0.1.10               | Private IP address of your VM                                                                             |
| name                    | eve                     | Label used for dynamic DNS entry creation (will create domain name of `$name.$region.cloudapp.azure.com`) |

## Sensitive Information/Variables

This project expects sensitive or unique information to be availalbe to
Terraform.  To help make this easier, `.gitignore` will ignore a file called
`secrets.tfvars`.  Place this file in the `terraform/` directory.  Its contents
should be a Terraform varaible file.  An example file ships with this
to give you a starting point.  Just copy it:

```bash
$ cp terraform/secrets.tfvars{.sample,}
```

And then open the file in your favorite text editor and fill in the blanks.

# Ansible

The Ansible playbook takes one variable as a parameter: the path to your EVE-NG
images on your local disk that you'd like to sync to the remote disk.  This
variables is called `images_path` and must be structured in the way that EVE-NG
would expect at the path `/opt/unetlab/addons/qemu/`.  As an example, if you're
creating an ASAv image, then the path to the image on the EVE-NG server might
be `/opt/unetlab/addons/qemu/asav-981/virtioa.qcow2`.  If your `images_path` is
set to `/tmp/eve-ng/images/`, then your directory structure would need to look
like this:

```bash
$ tree /tmp/eve-ng/
├── images
│   └── asav-981
│       └── virtioa.qcow2
```

In other words, you should have `/tmp/eve-ng/images/asav-981/virtioa.qcow2`.
This is because the playbook will copy everything in `images_path` directly
as-is, sub-directories and all, to `/opt/unetlab/addons/qemu/` on the remote
disk.

It is not recommended to have your images located in `/tmp`.  It was only used
for illustrative purposes.  If you'd like to keep your `images_path` in this
repository, you can do so!  In fact, the project defaults to usings the relative
path `images/` for `images_path`.  `.gitignore` will ensure that this directory
is not committed to the git repository.

> Note that this playbook will unconditionally create a partition on `/dev/sdc`
> and format it as `ext4`.  In my personal testing, this hasn't been an issue,
> but be warned that this could break something of yours.  I can't test every
> possible deployment.

# Usage

The instructions below will get you a running EVE-NG instance.  You can access
it at `https://$name.$region.cloudapp.azure.com`.  By default, this is
`https://eve.westus2.cloudapp.azure.com`.  The default credentials of
`admin/eve` can be used, and it is strongly recommended that you change these
after you log in for the first time.

> The service is still available over HTTP and currently does not redirect to
> HTTPS.  A pull request to implement redirection is welcome, but for now,
> make sure you're visiting `https://` and _not_ `http://`.  In addition, the
> Network Security Group is configured to drop traffic to port 80.

I don't personally utilize the `click to telnet` feature of the native console,
so the Network Security Group rules do not allow this functionality.  In order
to access a device, you will need to either use the HTML5 Console or you will
need to SSH to the server and then telnet to the port locally.  For example,
if the port on which the network device is listening is `32657`, you can SSH
to the server and then access its console with `telnet 127.0.0.1 32657`.

> I'm not likely to accept a pull request that opens the Network Security Group
> rules to the dynamic range of ports that EVE-NG uses.

## First Steps

You'll need to install both Terraform and Ansible.  Doing so is outside of the
scope of this document, but both Terraform and Ansible have excellent
installation guides.

- [Install Terraform](https://learn.hashicorp.com/terraform/getting-started/install)
- [Install Ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html)

## With `make`

This repository includes a [Makefile](Makefile).  It can be used to simplify
the process of deploying EVE-NG on Azure.  Note, however, that you still
need to pay attention to the previous sections.  Authentication information
and the `terraform/secrets.tfvars` must exist!

### Initial Deploy

For a one-command deployment that utilizes all defaults, you can simply
`make deploy`.  However, if you need or want to customize your deployment,
you can do so with environment variables, as shown below:

```bash
$ TERRAFORM_CMD=terraform-snap.terraform IMAGES_PATH=/tmp/images/ SSH_KEY=~/.ssh/id_rsa_eve_azure make deploy
```

### Syncing New Images

You can reuse the same command to sync new images, or you can use the
`make images` command if that's easier to remember.

### Resizing a VM

You can resize a VM with `VM_SIZE=Standard_D8s_v3 make resize`.  This will
either add or rewrite a `vm_size` variable in `terraform/secrets.tfvars`,
followed by doing a deploy again.

> If you don't specify `VM_SIZE`, it will default to this project's default
> of `Standard_D2s_v3`.

Alternatively, you can just edit `terraform/secrets.tfvars` yourself and rerun
`make deploy`.

### Destroying Everything

You can destroy everythin with `make destroy`.  Keep in mind that this will
delete all of your resources.

### Stopping a VM

Currently, stopping and starting a VM is not supported/implemented.  For now,
if you want to do that, you'll need to do so via Azure's web portal or command
line utility.

## Manually

You are welcome to use both Terraform and Ansible independently if you are
comfortable with doing so.  To apply the Terraform state, you can use the
following commands to apply the state and create the Ansible inventory:

```bash
$ pushd terraform/
$ terraform apply -var-file=secrets.tfvars -auto-approve
$ terraform output fqdn > ../inventory
$ popd
```

For Ansible, you can use this one:

```bash
$ ansible-playbook -u eve -i inventory playbook.yml
```

> The above assume all defaults are followed.  If you used something else,
> adjust as necessary.


# Caveat Emptor

This works for me, and hopefully it works for you, too.  However, you're
responsible for whatever this does.  This includes any financial charges, loss
of data, etc. that may result from the use of this project.

# License

MIT.  See [LICENSE](LICENSE) for more information.

# Thanks

- [@thelantamer](https://twitter.com/thelantamer) for the original inspiration
  building EVE-NG in a public cloud and the tip that `/etc/network/interfaces`
  _probably_ doesn't need to be modified.
