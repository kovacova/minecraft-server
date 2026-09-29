# Part 2: The Discord bot

**The goal:** anyone in your Discord types `/start` and the server wakes up.
`/status` says whether it's on.

**Do [Part 1](1-static-ip.md) first.** The bot tells people the address.

**Time:** 20 minutes. **Cost:** free (well within AWS's free tier).

## How it works

```
You type /start
      │
Discord ──► API Gateway ──► Lambda ──► "start the server"
            (a public URL)  (bot/index.mjs)
```

- **Lambda** runs a bit of code only when something calls it. No server to pay for.
- **API Gateway** gives that code a web address Discord can call.
- The bot is only allowed to **look at** servers and **start this one**. It can't
  stop, delete or create anything. Look at `aws_iam_role_policy.bot` in
  [`terraform/discord.tf`](../terraform/discord.tf). That's called *least privilege*.

The code is already written. You're connecting the pieces.

---

### Step 1: Create the Discord app

1. Go to **https://discord.com/developers/applications** and log in.
2. **New Application** → name it `Minecraft` → Create.
3. You're on **General Information**. Keep this tab open.

### Step 2: Give AWS the public key

1. On General Information, copy the **Public Key**. It's not a secret.
2. Open `terraform\terraform.tfvars` in Notepad and add:
   ```
   discord_public_key = "paste-it-here"
   ```
3. Save, then in PowerShell:
   ```powershell
   tofu apply
   ```
   It shows the bot pieces as **will be created**. Type `yes`.
4. Get the bot's web address:
   ```powershell
   tofu output discord_bot_url
   ```

✅ **Check:** a link like `https://abc123.execute-api.ca-central-1.amazonaws.com`

### Step 3: Tell Discord where the bot lives

1. Back on **General Information**, find **Interactions Endpoint URL**.
2. Paste the link from Step 2 → **Save Changes**.

✅ **Check:** it saves with no red error. Discord just tested your bot, and it passed.

*Red error? Make sure the public key in `terraform.tfvars` exactly matches the page,
then `tofu apply` again.*

### Step 4: Add the bot to your Discord server

1. Left menu → **Installation**.
2. Under **Installation Contexts**, tick **Guild Install**.
3. Under **Default Install Settings → Guild Install**, add the scope `applications.commands`.
4. **Save Changes**, then copy the **Install Link** at the top.
5. Open that link → pick your Discord server → Authorize.

✅ **Check:** Discord says the app was added.

### Step 5: Teach Discord the commands

This tells Discord that `/start` and `/status` exist. In PowerShell, from the
`minecraft-server` folder:

```powershell
powershell -ExecutionPolicy Bypass -File bot\register-commands.ps1
```

It asks for two things:

- **Application ID:** General Information page.
- **Bot token:** left menu → **Bot** → **Reset Token** → copy. **Never paste this
  anywhere else.** It's the bot's password. The script uses it once and doesn't save it.

✅ **Check:** it prints `Registered /start` and `Registered /status`.

### Step 6: Try it

In any channel of your Discord, type `/status`, then `/start`.

✅ **Check:** the bot answers. After `/start`, join in about 2 minutes. 🎉

---

## If something goes wrong

| What you see | What it means |
|---|---|
| "The application did not respond" | The bot crashed or timed out. See its logs: AWS console → **Lambda** → `minecraft-discord-bot` → **Monitor** → **View CloudWatch logs**. |
| The commands don't show up | Restart Discord (Ctrl+R). Commands can take a minute to appear. |
| "Interactions Endpoint URL could not be verified" | The public key doesn't match. Check Step 2. |

**Don't share the Install Link.** Anyone who adds the bot to their own server could
start yours. It would only cost cents and it turns itself off, but still.

## Ideas for later

- A `/stop` command. You'd have to give the bot one more permission. Where?
- Make `/status` say *who* is online. Hint: the server already knows (`sudo mc list`).
- Have the bot post in a channel when the server shuts itself down.
