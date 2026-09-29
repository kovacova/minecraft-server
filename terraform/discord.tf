# The Discord bot: Discord → API Gateway → Lambda → "start the server".
# Off until discord_public_key is set in terraform.tfvars.

locals {
  bot = var.discord_public_key == "" ? 0 : 1
}

data "archive_file" "bot" {
  type        = "zip"
  source_file = "${path.module}/../bot/index.mjs"
  output_path = "${path.module}/.build/bot.zip"
}

resource "aws_iam_role" "bot" {
  count = local.bot
  name  = "minecraft-discord-bot"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
}

resource "aws_iam_role_policy_attachment" "bot_logs" {
  count      = local.bot
  role       = aws_iam_role.bot[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Least privilege: the bot may look at servers, and start exactly one of them.
# It cannot stop, delete or create anything.
resource "aws_iam_role_policy" "bot" {
  count = local.bot
  name  = "start-minecraft-only"
  role  = aws_iam_role.bot[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = "ec2:DescribeInstances", Resource = "*" },
      { Effect = "Allow", Action = "ec2:StartInstances", Resource = aws_instance.server.arn },
    ]
  })
}

resource "aws_lambda_function" "bot" {
  count            = local.bot
  function_name    = "minecraft-discord-bot"
  role             = aws_iam_role.bot[0].arn
  runtime          = "nodejs22.x"
  handler          = "index.handler"
  filename         = data.archive_file.bot.output_path
  source_code_hash = data.archive_file.bot.output_base64sha256
  architectures    = ["arm64"]
  timeout          = 3 # Discord gives up after 3 seconds anyway

  environment {
    variables = {
      DISCORD_PUBLIC_KEY = var.discord_public_key
      INSTANCE_ID        = aws_instance.server.id
      SERVER_ADDRESS     = aws_eip.server.public_ip
    }
  }
}

# The public URL Discord sends slash commands to.
resource "aws_apigatewayv2_api" "bot" {
  count         = local.bot
  name          = "minecraft-discord-bot"
  protocol_type = "HTTP"
  target        = aws_lambda_function.bot[0].arn
}

resource "aws_lambda_permission" "bot" {
  count         = local.bot
  statement_id  = "discord-via-api-gateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.bot[0].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.bot[0].execution_arn}/*"
}
