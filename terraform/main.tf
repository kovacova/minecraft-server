terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region  = "ca-central-1" # the account's guardrails refuse every other region
  profile = var.aws_profile

  default_tags {
    tags = { Project = "minecraft" }
  }
}

data "aws_caller_identity" "me" {}

# Latest Amazon Linux 2023 for ARM (Graviton). Changes when AWS ships a new image,
# which would replace the server, so it is ignored after the first apply (see instance).
data "aws_ssm_parameter" "al2023_arm64" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64"
}

# ---------------------------------------------------------------- network

resource "aws_vpc" "main" {
  cidr_block           = "10.42.0.0/16"
  enable_dns_hostnames = true
  tags                 = { Name = "minecraft" }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.42.1.0/24"
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true
  tags                    = { Name = "minecraft-public" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Only Minecraft is open. There is no SSH port: shell access goes through
# SSM Session Manager, which needs no open port and no key file.
resource "aws_security_group" "minecraft" {
  name        = "minecraft"
  description = "Minecraft Java only"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Minecraft Java"
    from_port   = 25565
    to_port     = 25565
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ---------------------------------------------------------------- storage

# The world lives on its own disk, so the server can be destroyed and rebuilt
# without touching it. prevent_destroy makes Terraform refuse to delete it.
resource "aws_ebs_volume" "world" {
  availability_zone = var.availability_zone
  size              = var.world_disk_gb
  type              = "gp3"
  encrypted         = true
  tags              = { Name = "minecraft-world" }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_volume_attachment" "world" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.world.id
  instance_id = aws_instance.server.id
}

resource "aws_s3_bucket" "backups" {
  bucket = "minecraft-backups-${data.aws_caller_identity.me.account_id}"
}

resource "aws_s3_bucket_public_access_block" "backups" {
  bucket                  = aws_s3_bucket.backups.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "backups" {
  bucket = aws_s3_bucket.backups.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_lifecycle_configuration" "backups" {
  bucket = aws_s3_bucket.backups.id
  rule {
    id     = "expire-old-backups"
    status = "Enabled"
    filter { prefix = "backups/" }
    expiration { days = var.backup_retention_days }
    noncurrent_version_expiration { noncurrent_days = 7 }
  }
}

# ---------------------------------------------------------------- server

resource "aws_iam_role" "server" {
  name = "minecraft-server"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.server.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# The server may read and write its own backup bucket, nothing else.
resource "aws_iam_role_policy" "backups" {
  name = "backups"
  role = aws_iam_role.server.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["s3:ListBucket"], Resource = aws_s3_bucket.backups.arn },
      { Effect = "Allow", Action = ["s3:GetObject", "s3:PutObject"], Resource = "${aws_s3_bucket.backups.arn}/*" },
    ]
  })
}

resource "aws_iam_instance_profile" "server" {
  name = "minecraft-server"
  role = aws_iam_role.server.name
}

resource "aws_instance" "server" {
  ami                    = data.aws_ssm_parameter.al2023_arm64.value
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.minecraft.id]
  iam_instance_profile   = aws_iam_instance_profile.server.name

  # `shutdown` from inside (the idle watcher) stops the instance rather than deleting it.
  instance_initiated_shutdown_behavior = "stop"

  metadata_options {
    http_tokens = "required" # IMDSv2 only
  }

  root_block_device {
    volume_size = 12
    volume_type = "gp3"
    encrypted   = true
  }

  user_data = templatefile("${path.module}/../server/cloud-init.sh.tftpl", {
    accept_eula       = var.accept_minecraft_eula
    world_volume_id   = aws_ebs_volume.world.id
    minecraft_version = var.minecraft_version
    server_jar_url    = var.server_jar_url
    memory_gb         = var.server_memory_gb
    idle_minutes      = var.idle_minutes
    backup_bucket     = aws_s3_bucket.backups.bucket
    watch_py          = file("${path.module}/../server/mc-watch.py")
    backup_sh         = file("${path.module}/../server/mc-backup.sh")
    import_sh         = file("${path.module}/../server/import-world.sh")
    mc_py             = file("${path.module}/../server/mc")
  })
  user_data_replace_on_change = true

  lifecycle {
    ignore_changes = [ami]
  }

  tags = { Name = "minecraft" }
}
