# minecraft-server

A Java Minecraft server on AWS that costs almost nothing when nobody is playing.
It lives in its own AWS account, in Montreal (`ca-central-1`), and turns itself off
after 15 minutes with no players online.

This README explains *why* as well as *how*. Read the why, because it's the part that
transfers to every other cloud project.

## What's already true about the account

The organization's management account puts **guardrails** (a Service Control Policy) on
the Minecraft account. You're a full admin, but the policy sits above admin. Inside this account
nobody, root included, can:

- use any region except `ca-central-1`
- launch anything except ARM (Graviton) instances up to `xlarge` (16 GB)
- buy reserved capacity, savings plans, Marketplace products or domains
- leave the organization or close the account

Budget alerts email the owner at $10 and $25 a month. Break whatever you like. The walls hold.

## Architecture

```
            you (Minecraft client)
                    │ tcp/25565
┌─── VPC 10.42.0.0/16 ──────────────────────────────────┐
│  public subnet (ca-central-1a)                         │
│  ┌─ EC2 m7g.xlarge, Amazon Linux 2023 ─────────────┐   │
│  │ minecraft.service   java -jar server.jar        │   │
│  │ mc-watch.timer      empty 15 min → shutdown     │   │
│  │ /srv/minecraft  ◄── separate EBS disk (world)   │   │
│  └───────────┬─────────────────────────────────────┘   │
└──────────────┼─────────────────────────────────────────┘
               │ every stop: tar.gz ──► S3 minecraft-backups-<account>
   you ── SSM Session Manager (no SSH port, no key file) ──► shell
```

Decisions worth understanding:

| Choice | Why |
|---|---|
| World on its **own EBS volume** with `prevent_destroy` | Rebuild or resize the server freely; the world survives. Terraform refuses to delete the disk. |
| **No SSH, no port 22** | Session Manager authenticates with your AWS login. Nothing to brute-force, no `.pem` to lose. |
| `instance_initiated_shutdown_behavior = "stop"` | `shutdown -h now` inside the box *stops* the instance (disk kept, compute billing ends) rather than terminating it. |
| Backups on **every stop** | `ExecStopPost` runs after Java saves, while the network is still up. S3 versioning plus a 30-day expiry. |
| Whitelist on by default | The server has a public IP. Anyone can find it. |
| **Graviton (ARM)** | ~20% cheaper than x86 for the same performance; Java doesn't care. |

## First-time setup (laptop)

```bash
brew install awscli opentofu      # Mac. Windows: winget install Amazon.AWSCLI OpenTofu.Tofu
aws configure sso                 # start URL: the sign-in link from the invite email
                                  # region: ca-central-1, account: the Minecraft one,
                                  # role: the admin one, profile name: minecraft
aws sso login --profile minecraft
aws sts get-caller-identity --profile minecraft   # should name the Minecraft account
```

## Deploy

```bash
cd terraform
cp example.tfvars terraform.tfvars   # edit it: version, and the EULA line
tofu init
tofu plan      # READ THIS. It lists every resource it will create.
tofu apply
```

`minecraft_version` must match the version your world was last opened in, **or newer**.
Opening a world in an older version can corrupt it.

The server won't start until you set `accept_minecraft_eula = true`. Read the
[EULA](https://aka.ms/MinecraftEULA) first. Accepting it is your decision, so it's not
set by default.

First boot takes ~3 minutes (installs Java, downloads the server). Watch it:

```bash
$(tofu output -raw shell)                      # opens a shell on the server
sudo tail -f /var/log/minecraft-setup.log      # cloud-init
sudo journalctl -u minecraft -f                # the server itself
```

## Bring your world over

On your PC, the world is a folder in `%APPDATA%\.minecraft\saves\` (Windows) or
`~/Library/Application Support/minecraft/saves/` (Mac). Close Minecraft first, then:

1. Zip the world folder itself, the one with `level.dat` inside, e.g. `MyWorld.zip`.
2. Upload it:
   ```bash
   aws s3 cp MyWorld.zip s3://$(tofu output -raw backup_bucket)/import/ --profile minecraft
   ```
3. On the server:
   ```bash
   sudo import-world.sh MyWorld.zip
   ```

The old world is backed up by the stop, then kept beside the new one as `*.before-import.*`.

## Day to day

| I want to… | Do this |
|---|---|
| Start it | `aws ec2 start-instances --instance-ids $(tofu output -raw instance_id) --profile minecraft` |
| Find the address | `tofu refresh && tofu output address`. It changes every start. |
| Whitelist a friend | In the server shell: `sudo -u minecraft` … or in-game as op: `/whitelist add Name` |
| Make yourself op | Server shell, then send `op YourName` over RCON, or add it to `ops.json` while stopped |
| Stop it now | Just leave. It stops itself 15 min after the last player does. |
| Back up now | `sudo mc-backup.sh` |
| Restore | Download a `backups/*.tar.gz` from S3, stop the service, untar into `/srv/minecraft`, start. **Test this once before you need it.** |

## Your roadmap

In rough order. Each is a real skill, not busywork.

1. **Discord `/start`.** A Discord slash command, served by an AWS Lambda behind a
   Function URL, that verifies Discord's Ed25519 signature, calls `ec2:StartInstances`,
   and replies with the new IP. Give the Lambda's role permission for **this one
   instance only**. That's least privilege, and it's the core IAM lesson.
2. **Stable address.** The IP changes every start. Options: an Elastic IP ($3.65/mo
   even while stopped), or the Lambda updating a Route 53 record. Compare the costs.
3. **Remote Terraform state.** Your state file is on your laptop. Move it to an S3
   backend with locking, so two people can run `apply` without corrupting it.
4. **CloudWatch.** Alarm on the instance running for more than 6 hours, and send
   server logs to CloudWatch Logs.
5. **GitHub Actions + OIDC.** `tofu plan` on every pull request, with **no stored AWS keys**.
   GitHub proves its identity to AWS directly.
6. **Performance.** Try Paper (`server_jar_url`), Aikar's JVM flags, and the `spark`
   profiler. Measure before and after.
7. **Break it on purpose.** `tofu destroy` everything except the world disk, then rebuild.
   Restore from a backup onto a fresh disk. You're done when both feel boring.

## Cost

About $0.18/h while running (m7g.xlarge), about $2/mo for disks when stopped, and pennies
for S3. Playing 20–60 h a month comes to **$7–14**. `m7g.large` halves the hourly
price and is plenty for vanilla.
