# A fixed public address. Without this, AWS hands the server a new IP every
# time it starts. An Elastic IP stays the same forever, running or stopped.
# Cost: $0.005/hour, all the time (~$3.65/month), which is the same price the
# server already paid for its changing IP while running.
resource "aws_eip" "server" {
  domain   = "vpc"
  instance = aws_instance.server.id
  tags     = { Name = "minecraft" }
}
