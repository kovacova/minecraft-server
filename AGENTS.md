# AGENTS.md: working on minecraft-server

For any AI agent (or person) changing this repo. Read it all before changing anything.

## What this is, and who it's for

A Java Minecraft server on AWS for two siblings: Tina (Mac, in BC, Canada) and her
younger brother, "Lil Bro" (Windows, in Slovakia). He's a CS student, and this is
his learning project. **He does the engineering; we make it possible and
understandable.** He deployed it himself on day one by reading the code, and that's
the spirit to protect.

## The rules

### This repo is public
- **Never commit** AWS account IDs, account names, the SSO portal URL, anyone's email,
  Discord tokens, or real names beyond "Lil Bro". Those stay in the owner's private notes.
- `*.tfvars`, `*.tfstate` and `.terraform/` are gitignored and must stay that way. Settings
  and state are personal.
- Before every push, grep the diff for secrets and 12-digit account numbers.

### Every instruction works on Windows *and* Mac
- Where commands differ, show both, side by side (a two-column table works well).
- Where they're identical, say "same on Windows and Mac".
- Label **server shell** commands: they run on Linux, so they're the same for everyone.
- Anything that runs on the server must keep **LF line endings** (`.gitattributes`). Git for
  Windows would otherwise add `\r`, and bash breaks on first boot. `*.ps1` stays CRLF.

### Guides are for a learner, and short
- Numbered steps, one action each, with a **✅ Check:** after each step so he knows it worked.
- Explain *why* in one line, not a paragraph. Tina's words: "even that repo readme was A
  LOT". He was mildly overwhelmed, then did it anyway. Less is more.
- End with **"Ideas for later"**, questions and hints rather than answers. Leave him
  things to build. Don't build all of them for him.
- New guides go in `docs/N-name.md`, and are linked from the README and from the previous guide's "Next".

### The world is sacred
- The world lives on its **own EBS volume** with `prevent_destroy`. Never move it onto
  the root disk. Never remove `prevent_destroy`.
- `stop_instance_before_detaching = true` makes sure Minecraft saves before the disk is
  unplugged. Keep it.
- Every stop backs up to S3 (versioned, 30 days). Don't break `ExecStopPost`.
- **A world can only be opened by its own Minecraft version or newer.** Never set
  `minecraft_version` older than a world on the server. Warn loudly about snapshots:
  they upgrade *every* world on the server.

### Decisions that are theirs, not ours
- **The Minecraft EULA.** `accept_minecraft_eula` defaults to `false`, and a person sets it.
  Never default it to true or accept it in a script.
- Anything that costs real money every month. Say what it costs before adding it.

### The AWS account has guardrails
An organization policy (SCP) sits above admin in this account:
- **Montreal (`ca-central-1`) only.** Global services (IAM, STS, CloudFront, Route 53,
  ACM, KMS, S3 bucket listing, pricing, billing) are exempt.
- **Graviton instances up to `xlarge`** (t4g, m7g/m8g, c7g/c8g).
- No reserved instances, savings plans, Marketplace or domain purchases.

Design within these. An "explicit deny in a service control policy" error means the
guardrail, not a bug. Suggest widening to the owner. Don't work around it.

## How the code works (the non-obvious bits)

- **`server/cloud-init.sh.tftpl`** runs once, on first boot. It's a Terraform template: shell
  variables are written `$${like_this}`. Files embedded with `file()` (`mc-watch.py`,
  `mc-backup.sh`, `mc`, `import-world.sh`) are **not** templated, so they use plain `${...}`.
- **Changing that template, or anything it embeds, replaces the server** on the next
  `tofu apply` (`user_data_replace_on_change`). That's safe thanks to the rules above, but
  it gives a new instance, and players get kicked. Say so in guides.
- **Java version:** read from Mojang's version metadata (`javaVersion.majorVersion`), never
  hardcoded. Minecraft 26.x needs Java 25. Hardcoding 21 once crash-looped the server.
- **Idle shutdown:** `mc-watch.timer` asks over RCON how many players are online. After 15
  empty minutes it stops Minecraft (which saves and backs up), then powers off. RCON (port 25575) is
  reachable only from the server itself, because the security group opens only 25565.
- **No SSH.** A shell is SSM Session Manager (`tofu output shell`). Don't open port 22.
- **The Discord bot** (`bot/index.mjs`): no dependencies, and it verifies Discord's Ed25519
  signature with Node's crypto. Its IAM role may describe instances and **start only this
  one**. Keep it least-privilege: every new ability is a deliberate, named permission.
- **The Elastic IP** is the fixed address the bot reports.

## Testing

- `tofu validate`, then render the cloud-init template with `tofu console` and run
  `bash -n` on the result. `python3 -m py_compile` and `bash -n` on the scripts.
- **Never call `/start`, `StartInstances` or anything else with side effects against the
  real account while testing.** A test once started the real server by accident. Use
  `--dry-run`, read-only calls, or mocks.
- A real deploy is Lil Bro's `tofu apply`. Say plainly what was and wasn't tested.

## Commits

- Imperative subject under ~60 characters that says what changed. A body only when the *why*
  isn't obvious. Batch by meaning.
- Push after committing. Never force-push.
