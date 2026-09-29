output "instance_id" {
  value = aws_instance.server.id
}

output "backup_bucket" {
  value = aws_s3_bucket.backups.bucket
}

output "address" {
  description = "Changes every time the server starts; the Discord bot should report it"
  value       = "${aws_instance.server.public_ip}:25565"
}

output "shell" {
  value = "aws ssm start-session --profile ${var.aws_profile} --target ${aws_instance.server.id}"
}
