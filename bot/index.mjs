// The Discord bot. Discord sends every slash command here (through API Gateway);
// this checks the message really came from Discord, then starts the server or
// reports on it. No libraries: Node's crypto verifies the signature and the AWS
// SDK is built into Lambda.
import crypto from "node:crypto";
import { EC2Client, DescribeInstancesCommand, StartInstancesCommand } from "@aws-sdk/client-ec2";

const { DISCORD_PUBLIC_KEY, INSTANCE_ID, SERVER_ADDRESS } = process.env;
const ec2 = new EC2Client({});

// Discord signs every request with Ed25519. Anything that fails the check is
// refused. Discord tests this on purpose when you save the endpoint URL.
const discordKey = crypto.createPublicKey({
  key: { kty: "OKP", crv: "Ed25519", x: Buffer.from(DISCORD_PUBLIC_KEY, "hex").toString("base64url") },
  format: "jwk",
});

function fromDiscord(event, body) {
  const signature = event.headers["x-signature-ed25519"];
  const timestamp = event.headers["x-signature-timestamp"];
  if (!signature || !timestamp) return false;
  return crypto.verify(null, Buffer.from(timestamp + body), discordKey, Buffer.from(signature, "hex"));
}

const reply = (content) => ({
  statusCode: 200,
  headers: { "content-type": "application/json" },
  body: JSON.stringify({ type: 4, data: { content } }), // 4 = "reply with a message"
});

async function server() {
  const out = await ec2.send(new DescribeInstancesCommand({ InstanceIds: [INSTANCE_ID] }));
  const instance = out.Reservations[0].Instances[0];
  const ip = SERVER_ADDRESS || instance.PublicIpAddress;
  return { state: instance.State.Name, address: ip ? `${ip}:25565` : "(no address yet)" };
}

async function start() {
  const { state, address } = await server();
  if (state === "running") return reply(`🟢 Already on! Join at \`${address}\``);
  if (state === "pending") return reply(`🟡 Already waking up. Join at \`${address}\` in a minute or two.`);
  if (state === "stopping") return reply("🟠 It's shutting down right now. Try `/start` again in a minute.");
  await ec2.send(new StartInstancesCommand({ InstanceIds: [INSTANCE_ID] }));
  return reply(`⛏️ Waking up the server! Join at \`${address}\` in about 2 minutes.`);
}

async function status() {
  const { state, address } = await server();
  const words = {
    running: `🟢 On. Join at \`${address}\``,
    pending: "🟡 Starting up…",
    stopping: "🟠 Shutting down…",
    stopped: "⚫ Off. Type `/start` to wake it.",
  };
  return reply(words[state] ?? `State: ${state}`);
}

export async function handler(event) {
  const body = event.isBase64Encoded ? Buffer.from(event.body, "base64").toString() : event.body;
  if (!fromDiscord(event, body)) return { statusCode: 401, body: "bad signature" };

  const interaction = JSON.parse(body);
  // Discord's "are you there?" check, sent when the endpoint URL is saved.
  if (interaction.type === 1) {
    return { statusCode: 200, headers: { "content-type": "application/json" }, body: JSON.stringify({ type: 1 }) };
  }

  switch (interaction.data?.name) {
    case "start": return start();
    case "status": return status();
    default: return reply("I only know `/start` and `/status`.");
  }
}
