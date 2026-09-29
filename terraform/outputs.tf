output "instance_id" {
  value = aws_instance.server.id
}

output "backup_bucket" {
  value = aws_s3_bucket.backups.bucket
}

output "address" {
  description = "The server's fixed address. Put this in Minecraft"
  value       = "${aws_eip.server.public_ip}:25565"
}

output "discord_bot_url" {
  description = "Paste into Discord: Developer Portal → your app → General Information → Interactions Endpoint URL"
  value       = local.bot == 1 ? aws_apigatewayv2_api.bot[0].api_endpoint : "(set discord_public_key in terraform.tfvars first)"
}

output "shell" {
  value = "aws ssm start-session --profile ${var.aws_profile} --target ${aws_instance.server.id}"
}
