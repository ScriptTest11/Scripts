# MCH Main Script - Final Version
# Multi-Source HR File Validation System

# Install and import required modules (if needed)
# Install-Module -Name Posh-SSH -Force -Scope CurrentUser -AllowClobber
# Import-Module Posh-SSH

# Import the unified validation modules
Import-Module -Name "Final_UnifiedValidator.psm1" -Force
Import-Module -Name "Final_SourceConfigurations.psm1" -Force

# ===========================================
# CONFIGURATION SECTION
# ===========================================

# Define paths and filenames - UPDATE THESE VALUES
$HCMFolder = "C:\HR_Files\Incoming"              # Where to look for incoming files
$HCMbackupFolder = "C:\HR_Files\Backup"          # Where to store backups and reports
$HCMFileName = "MCH_employees.csv"               # Expected filename
$TempDir = "C:\HR_Files\Temp"                    # Temporary processing directory

# Email configuration - UPDATE THESE VALUES
$emailFrom = "hr-system@company.com"             # From address
$HCMemailTo = "hr-team@company.com,manager@company.com"  # To addresses (comma-separated)
$sailpointTeamCC = "sailpoint-team@company.com"  # CC addresses (comma-separated)

# Parse email addresses
$sailpointTeamCCArray = $sailpointTeamCC -split ',' | Where-Object { $_.Trim() -ne '' } | ForEach-Object { $_.Trim() }
$HCMemailToArray = $HCMemailTo -split ',' | Where-Object { $_.Trim() -ne '' } | ForEach-Object { $_.Trim() }

$smtpServer = "smtp.company.com"                 # SMTP server

# ===========================================
# MAIN PROCESSING
# ===========================================

Write-Host "=========================================="
Write-Host "MCH HR File Validation Script Started"
Write-Host "Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host "=========================================="

try {
    $fullPath = Join-Path -Path $HCMFolder -ChildPath $HCMFileName
    $today = Get-Date -Format "yyyy-MM-dd"

    if (Test-Path $fullPath) {
        Write-Host "✅ File Found: $HCMFileName"
        Write-Host "   Full path: $fullPath"
        
        # Create timestamped backup filename
        $timestamp = Get-Date -Format "yyyyMMddHHmmss"
        $backupFileName = "$HCMFileName-$timestamp"
        $backupFilePath = Join-Path $TempDir $backupFileName

        # Ensure temp directory exists
        if (-not (Test-Path $TempDir)) {
            New-Item -Path $TempDir -ItemType Directory -Force
            Write-Host "Created temp directory: $TempDir"
        }

        # Copy file to temp location for processing
        Copy-Item -Path $fullPath -Destination $backupFilePath -Force
        Write-Host "✅ File copied to temp location: $backupFilePath"

        # ===========================================
        # GET MCH SOURCE CONFIGURATION
        # ===========================================
        Write-Host "🔧 Loading MCH source configuration..."
        $sourceConfig = Get-SourceConfig -SourceName "MCH"
        
        # Validate the configuration
        if (-not (Validate-SourceConfig -Config $sourceConfig)) {
            Write-Error "❌ MCH source configuration validation failed"
            exit 1
        }

        Write-Host "✅ MCH configuration loaded successfully"
        Write-Host "   Expected headers: $($sourceConfig.HeaderCount)"
        Write-Host "   Date format: $($sourceConfig.DateFormat)"
        Write-Host "   Mandatory fields: $($sourceConfig.MandatoryFields.Count)"
        Write-Host "   Process validation: $($sourceConfig.processValidation)"
        Write-Host "   Termination threshold: $($sourceConfig.LcsCalculationRules.TerminationThreshold)"

        # ===========================================
        # PREPARE EMAIL CONFIGURATION
        # ===========================================
        $emailConfig = @{
            FromAddress = $emailFrom
            ToAddress = $HCMemailToArray
            CcAddress = $sailpointTeamCCArray
            SmtpServer = $smtpServer
            Subject = "SailPoint - MCH HR File Validation $today"
        }

        # ===========================================
        # VALIDATION FLAGS
        # ===========================================
        $validationProcessFlag = $true

        Write-Host "🚀 Starting unified validation for MCH source..."

        # ===========================================
        # START UNIFIED VALIDATION
        # ===========================================
        $validationResult = Start-UnifiedValidation `
            -SourceConfig $sourceConfig `
            -CsvFilePath $backupFilePath.Trim() `
            -EmailConfig $emailConfig `
            -HCMbackupFolder $HCMbackupFolder `
            -ValidationProcessFlag $validationProcessFlag

        # ===========================================
        # PROCESS RESULTS
        # ===========================================
        if ($validationResult -eq 0) {
            Write-Host "✅ MCH validation completed successfully"
            Write-Host "   File has been processed and backed up"
        } else {
            Write-Host "❌ MCH validation completed with issues (Exit Code: $validationResult)"
            Write-Host "   Check email reports for details"
        }

        # Clean up temp file
        if (Test-Path $backupFilePath) {
            Remove-Item $backupFilePath -Force
            Write-Host "🧹 Cleaned up temp file: $backupFilePath"
        }

        Write-Host "=========================================="
        Write-Host "MCH Processing completed with exit code: $validationResult"
        Write-Host "=========================================="
        
        exit $validationResult
        
    } else {
        Write-Host "❌ $HCMFileName not received today"
        Write-Host "   Expected location: $fullPath"

        # ===========================================
        # SEND FILE MISSING NOTIFICATION
        # ===========================================
        $subject = "SailPoint - MCH HR File Missing Notification - $today"
        $body = @"
<html>
<body>
<h2>MCH HR File Missing Notification</h2>
<p><strong>Hello Team,</strong></p>
<p>This is a notification that the MCH HR file <strong>$HCMFileName</strong> was not received on <strong>$today</strong>.</p>

<h3>Details:</h3>
<ul>
<li><strong>Expected File:</strong> $HCMFileName</li>
<li><strong>Expected Location:</strong> $fullPath</li>
<li><strong>Check Time:</strong> $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</li>
</ul>

<h3>Next Steps:</h3>
<ol>
<li>Please upload the file to the shared location at your earliest convenience</li>
<li>Verify the filename matches exactly: <strong>$HCMFileName</strong></li>
<li>If you experience any issues or need assistance, please contact the SailPoint team</li>
</ol>

<p>Thank you for your attention.</p>
<br>
<p><strong>Thank You</strong><br>
<em>Cybersecurity Team</em><br>
<em>Automated HR File Validation System</em></p>
</body>
</html>
"@

        # Send file missing notification
        try {
            Send-MailMessage -From $emailFrom `
                           -To $HCMemailToArray `
                           -Cc $sailpointTeamCCArray `
                           -Subject $subject `
                           -Body $body `
                           -BodyAsHtml `
                           -SmtpServer $smtpServer
            
            Write-Host "✅ File missing notification sent successfully"
        } catch {
            Write-Error "❌ Failed to send file missing notification: $_"
        }

        Write-Host "=========================================="
        Write-Host "MCH Processing completed - File not found"
        Write-Host "=========================================="
        
        exit 0  # Not an error - just file not received yet
    }
}
catch {
    Write-Host "=========================================="
    Write-Host "❌ CRITICAL ERROR in MCH processing: $_"
    Write-Host "=========================================="
    
    # Send error notification
    try {
        $errorSubject = "SailPoint - MCH Processing Error - $today"
        $errorBody = @"
<html>
<body>
<h2>MCH Processing Error</h2>
<p><strong>Critical Error Occurred:</strong></p>
<pre>$_</pre>
<p><strong>Time:</strong> $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>
<p><strong>File:</strong> $HCMFileName</p>
<p>Please investigate and resolve the issue.</p>
<p><em>Automated HR File Validation System</em></p>
</body>
</html>
"@
        
        Send-MailMessage -From $emailFrom `
                       -To $HCMemailToArray `
                       -Cc $sailpointTeamCCArray `
                       -Subject $errorSubject `
                       -Body $errorBody `
                       -BodyAsHtml `
                       -SmtpServer $smtpServer
    } catch {
        Write-Host "❌ Failed to send error notification: $_"
    }
    
    exit 1
}

Write-Host "MCH Script Completed at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"