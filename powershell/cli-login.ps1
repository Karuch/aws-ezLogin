param(
    [string]$awsKey,
    [string]$awsSecret,
    [string]$region,
    [string]$profile,
    [string]$roleName,
    [string]$accountId
)

# ========================================================
# Function to check if running as Administrator
# ========================================================
function Test-Admin {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal   = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

# ========================================================
# Check if AWS CLI is installed
# ========================================================
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Host "❌ AWS CLI not found."

    # Check if user is admin BEFORE trying to install
    if (-not (Test-Admin)) {
        Write-Host "⚠️ You must run this script as Administrator to install AWS CLI."
        exit 1
    }

    $choice = Read-Host "👉 Do you want to install AWS CLI v2 now? (y/n)"
    if ($choice -match '^(y|Y)$') {
        Write-Host "⬇️ Downloading and installing AWS CLI..."
        $installer = "$env:TEMP\AWSCLIV2.msi"
        Invoke-WebRequest "https://awscli.amazonaws.com/AWSCLIV2.msi" -OutFile $installer
        Start-Process msiexec.exe -ArgumentList "/i `"$installer`" /qn" -Wait
        Remove-Item $installer
        Write-Host "✅ AWS CLI installed successfully. Please restart your shell."
        exit
    } else {
        Write-Host "⚠️ AWS CLI is required. Exiting..."
        exit 1
    }
}

# ========================================================
# Usage helper
# ========================================================
function Show-Usage {
    Write-Host "❌ Missing required arguments.`n"
    if (-not $awsKey)     { Write-Host "   → Missing: -awsKey" }
    if (-not $awsSecret)  { Write-Host "   → Missing: -awsSecret" }
    if (-not $region)     { Write-Host "   → Missing: -region" }
    if (-not $profile)    { Write-Host "   → Missing: -profile" }
    if (-not $roleName)   { Write-Host "   → Missing: -roleName" }
    if (-not $accountId)  { Write-Host "   → Missing: -accountId" }

    Write-Host "`n👉 Example usage:"
    Write-Host "powershell -ExecutionPolicy Bypass -File cli-login.ps1 `"
    Write-Host "  -awsKey [AccessKey] `"
    Write-Host "  -awsSecret [SecretKey] `"
    Write-Host "  -region il-central-1 `"
    Write-Host "  -profile talk `"
    Write-Host "  -roleName [roleName] `"
    Write-Host "  -accountId 012345678910"
    exit 1
}

if (-not $awsKey -or -not $awsSecret -or -not $region -or -not $profile -or -not $roleName -or -not $accountId) {
    Show-Usage
}

# ========================================================
# Prompt MFA code
# ========================================================
$MfaCode = Read-Host "🔑 Enter MFA code"

# ========================================================
# Build Role ARN
# ========================================================
$RoleArn   = "arn:aws:iam::${accountId}:role/${roleName}"
$SessionName = "$roleName-$(Get-Date -UFormat %s)"

# ========================================================
# Configure base profile
# ========================================================
Write-Host "📂 Creating base profile if not exist..."
aws configure set aws_access_key_id $awsKey --profile "$profile-malamteam-infra"
aws configure set aws_secret_access_key $awsSecret --profile "$profile-malamteam-infra"
aws configure set region $region --profile "$profile-malamteam-infra"
aws configure set output json --profile "$profile-malamteam-infra"

# ========================================================
# Auto-detect MFA ARN
# ========================================================
Write-Host "🔍 Detecting MFA device for user $profile..."
try {
    $MfaArn = aws iam list-mfa-devices `
        --user-name $profile `
        --profile "$profile-malamteam-infra" `
        --query 'MFADevices[0].SerialNumber' `
        --output text
    if (-not $MfaArn -or $MfaArn -eq "None") {
        Write-Host "❌ No MFA device found for user $profile."
        exit 1
    }
} catch {
    Write-Host "❌ Failed to detect MFA device for $profile."
    exit 1
}

# ========================================================
# Get MFA session token
# ========================================================
Write-Host "🔑 Getting MFA session token..."
try {
    $MfaCreds = aws sts get-session-token `
        --serial-number $MfaArn `
        --token-code $MfaCode `
        --profile "$profile-malamteam-infra" `
        --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' `
        --output text
} catch {
    Write-Host "❌ Failed to get MFA session token. Check your code or profile."
    exit 1
}

$creds = $MfaCreds -split "`t"
$env:AWS_ACCESS_KEY_ID     = $creds[0]
$env:AWS_SECRET_ACCESS_KEY = $creds[1]
$env:AWS_SESSION_TOKEN     = $creds[2]

# ========================================================
# Assume Role
# ========================================================
Write-Host "🌀 Assuming role: $roleName"
try {
    $RoleCreds = aws sts assume-role `
        --role-arn $RoleArn `
        --role-session-name $SessionName `
        --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' `
        --output text
} catch {
    Write-Host "❌ Failed to assume role $roleName"
    exit 1
}

$creds = $RoleCreds -split "`t"

# Save creds to the requested profile
aws configure set aws_access_key_id $creds[0] --profile $profile
aws configure set aws_secret_access_key $creds[1] --profile $profile
aws configure set aws_session_token $creds[2] --profile $profile
aws configure set region $region --profile $profile
aws configure set output json --profile $profile

# Make this the active profile for the current session
$env:AWS_PROFILE = $profile

Write-Host "✅ Role assumed successfully!"
Write-Host ""
Write-Host "🔍 Current identity:"
aws sts get-caller-identity

Write-Host ""
Write-Host "👉 To switch to this profile (`$profile`), run:"
Write-Host "    `$env:AWS_PROFILE = '$profile'"

