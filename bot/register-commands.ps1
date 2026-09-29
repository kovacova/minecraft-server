# Tells Discord that your app has /start and /status. Run once (again only if
# you add a command). The token is used for this one request and never saved.
$appId = Read-Host "Application ID (Developer Portal > General Information)"
$secure = Read-Host "Bot token (Developer Portal > Bot > Reset Token)" -AsSecureString
$token = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
  [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure))

$commands = @(
  @{ name = "start";  description = "Wake up the Minecraft server" },
  @{ name = "status"; description = "Is the Minecraft server on?" }
) | ConvertTo-Json

Invoke-RestMethod -Method Put `
  -Uri "https://discord.com/api/v10/applications/$appId/commands" `
  -Headers @{ Authorization = "Bot $token" } `
  -ContentType "application/json" -Body $commands |
  ForEach-Object { "Registered /$($_.name)" }
