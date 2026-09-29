# Part 1: A fixed address

**The problem:** every time the server wakes up, AWS gives it a new IP, so the
address in Minecraft keeps breaking.

**The fix:** an *Elastic IP*, an address you keep forever. The code is already
written ([`terraform/static-ip.tf`](../terraform/static-ip.tf), 5 lines). You
just turn it on.

**Time:** 5 minutes. **Cost:** about $3.65/month.

---

### Step 1: Get the new code

In PowerShell, in the `minecraft-server` folder:

```powershell
git pull
cd terraform
tofu init
```

`tofu init` is needed because the new code uses one more plugin.

✅ **Check:** it ends with *"OpenTofu has been successfully initialized!"*

### Step 2: Fix the EULA line (if you haven't)

Open `terraform.tfvars` in Notepad. Make sure this line has **no `#`** in front:

```
accept_minecraft_eula = true
```

### Step 3: Apply

```powershell
tofu apply
```

Read the plan before typing `yes`. You should see:

- `aws_eip.server` **will be created**. That's your address.
- A few small updates.

If it says the server **must be replaced**, that's OK too. It stops the server
cleanly first, and your world is on its own disk.

Type `yes`.

✅ **Check:** *"Apply complete!"*

### Step 4: Get your address

```powershell
tofu output address
```

✅ **Check:** you get something like `"15.222.x.x:25565"`.

### Step 5: Update Minecraft

Multiplayer → select the server → **Edit** → paste the new address → Done.

Tell your friends. This address never changes again. 🎉

---

**What you learned:** a *public IP* normally belongs to AWS and gets recycled.
An *Elastic IP* belongs to your account until you release it. That's why it
costs a little even while the server is off.

**Next:** [Part 2: the Discord bot](2-discord-bot.md)
