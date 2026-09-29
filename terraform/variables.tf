variable "aws_profile" {
  description = "AWS CLI profile from `aws configure sso` for the Minecraft account"
  type        = string
  default     = "minecraft"
}

variable "availability_zone" {
  description = "The server and its world disk must share one zone"
  type        = string
  default     = "ca-central-1a"
}

variable "instance_type" {
  description = "Graviton only; the account refuses anything above xlarge"
  type        = string
  default     = "m7g.xlarge" # 4 vCPU, 16 GB
}

variable "server_memory_gb" {
  description = "Java heap. Leave ~3 GB of the instance for the OS"
  type        = number
  default     = 12
}

variable "minecraft_version" {
  description = "Vanilla release, e.g. 1.21.8. Must be the world's version or newer, never older"
  type        = string
  default     = "latest"
}

variable "server_jar_url" {
  description = "Optional: a Paper/Fabric/Purpur jar URL. Overrides minecraft_version when set"
  type        = string
  default     = ""
}

variable "world_disk_gb" {
  type    = number
  default = 20
}

variable "idle_minutes" {
  description = "Stop the server after this long with nobody online"
  type        = number
  default     = 15
}

variable "backup_retention_days" {
  type    = number
  default = 30
}

variable "accept_minecraft_eula" {
  description = "Read https://aka.ms/MinecraftEULA first. The server will not start until this is true"
  type        = bool
  default     = false
}

variable "discord_public_key" {
  description = "Discord Developer Portal → your app → General Information → Public Key. Not a secret"
  type        = string
  default     = ""
}
