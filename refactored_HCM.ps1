
Write-Host "================================================================================"
Write-Host "HCM HR FILE VALIDATION AND PROCESSING SYSTEM"
Write-Host "================================================================================"
Write-Host "[INFO] Script execution started at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host "================================================================================"

Write-Host "`n[INFO] Checking and installing required modules..."

# Install Posh-SSH module for SFTP operations
Write-Host "[INFO] Installing Posh-SSH module (if not already installed)..."
try {
    Install-Module -Name Posh-SSH -Force -Scope CurrentUser -AllowClobber -ErrorAction Stop
    Write-Host "[SUCCESS] Posh-SSH module installed/verified"
} catch {
    Write-Host "[ERROR] Failed to install Posh-SSH module: $_"
    exit 1
}

# Import Posh-SSH module
Write-Host "[INFO] Importing Posh-SSH module..."
try {
    Import-Module Posh-SSH -ErrorAction Stop
    Write-Host "[SUCCESS] Posh-SSH module imported"
} catch {
    Write-Host "[ERROR] Failed to import Posh-SSH module: $_"
    exit 1
}

# Import custom modules (validation and source configuration)
Write-Host "[INFO] Importing custom validation module..."
Import-Module -Name "" -Force

Write-Host "[INFO] Importing source configuration module..."
Import-Module -Name "" -Force

Write-Host "[SUCCESS] All modules loaded successfully"

function Run-HCM-FileMover {
    param (
        [string]$password,
        [string]$sftpUser,
        [string]$sftpHost,
        [string]$HCMFolder,
        [string]$HCMbackupFolder,
        [string]$HCMFileName,
        [string]$emailFrom,
        [string]$HCMemailTo,
        [string]$sailpointTeamCC
    )
  
    Write-Host "`n================================================================================"
    Write-Host "[INFO] HCM FILE PROCESSING FUNCTION INITIATED"
    Write-Host "================================================================================"
    
    # --------------------------------------------------------------------------------
    # STEP 1: Parse and validate email addresses
    # --------------------------------------------------------------------------------
    Write-Host "`n[INFO] Step 1: Parsing email configuration..."
    Write-Host "[DEBUG] Raw CC addresses: $sailpointTeamCC"
    Write-Host "[DEBUG] Raw To addresses: $HCMemailTo"
    
    # Parse comma-separated CC email addresses and remove empty entries
    $sailpointTeamCCArray = $sailpointTeamCC -split ',' | Where-Object { $_.Trim() -ne '' } | ForEach-Object { $_.Trim() }
    Write-Host "[INFO] Parsed CC addresses: $($sailpointTeamCCArray.Count) recipients"
    if ($sailpointTeamCCArray.Count -gt 0) {
        Write-Host "[DEBUG] CC List: $($sailpointTeamCCArray -join ', ')"
    }
    
    # Parse comma-separated To email addresses and remove empty entries
    $HCMemailToArray = $HCMemailTo -split ',' | Where-Object { $_.Trim() -ne '' } | ForEach-Object { $_.Trim() }
    Write-Host "[INFO] Parsed To addresses: $($HCMemailToArray.Count) recipients"
    if ($HCMemailToArray.Count -gt 0) {
        Write-Host "[DEBUG] To List: $($HCMemailToArray -join ', ')"
    }
    
    # Define SMTP server for email sending
    $smtpServer = "AZSCUSEXP01.ONERHEEM.com"
    Write-Host "[INFO] SMTP Server: $smtpServer"
    Write-Host "[SUCCESS] Email configuration parsed successfully"
    
    # --------------------------------------------------------------------------------
    # STEP 2: Setup SFTP credentials
    # --------------------------------------------------------------------------------
    Write-Host "`n[INFO] Step 2: Setting up SFTP credentials..."
    Write-Host "[DEBUG] SFTP Username: $sftpUser"
    Write-Host "[DEBUG] SFTP Host: $sftpHost"
    
    # Convert plain text password to secure string
    $SecurePass = ConvertTo-SecureString $password -AsPlainText -Force
    Write-Host "[SUCCESS] Password converted to secure string"
    
    # Create PowerShell credential object
    $Credential = New-Object System.Management.Automation.PSCredential ($sftpUser, $SecurePass)
    Write-Host "[SUCCESS] SFTP credentials object created"

    # --------------------------------------------------------------------------------
    # STEP 3: Setup temporary directory for local file operations
    # --------------------------------------------------------------------------------
    Write-Host "`n[INFO] Step 3: Setting up temporary directory..."
    $TempDir = Join-Path $env:TEMP "SFTPTemp"
    Write-Host "[DEBUG] Temporary directory path: $TempDir"
    
    if (!(Test-Path -Path $TempDir)) {
        Write-Host "[INFO] Creating temporary directory..."
        New-Item -Path $TempDir -ItemType Directory -Force | Out-Null
        Write-Host "[SUCCESS] Temporary directory created"
    } else {
        Write-Host "[INFO] Temporary directory already exists"
    }

    Write-Host "[SUCCESS] Temporary directory ready: $TempDir"

    # --------------------------------------------------------------------------------
    # STEP 4: Main processing block with error handling
    # --------------------------------------------------------------------------------
    try {
        Write-Host "`n================================================================================"
        Write-Host "[INFO] STARTING MAIN PROCESSING WORKFLOW"
        Write-Host "================================================================================"
        
        # --------------------------------------------------------------------------------
        # STEP 4.1: Establish SFTP connection
        # --------------------------------------------------------------------------------
        Write-Host "`n[INFO] Step 4.1: Establishing SFTP connection..."
        $SFTPSession = New-SFTPSession -ComputerName $sftpHost -Credential $Credential -AcceptKey -Verbose
        Write-Host "[SUCCESS] SFTP session established to $sftpHost"
        Write-Host "[DEBUG] Session ID: $($SFTPSession.SessionId)"
        
        # --------------------------------------------------------------------------------
        # STEP 4.2: List files in HCM source folder
        # --------------------------------------------------------------------------------
        Write-Host "`n[INFO] Step 4.2: Scanning HCM source folder for files..."
        Write-Host "[DEBUG] Source folder: $HCMFolder"
        
        $files = Get-SFTPChildItem -SessionId $SFTPSession.SessionId -Path $HCMFolder
        Write-Host "[SUCCESS] Connected to $HCMFolder"
        Write-Host "[INFO] Found $($files.Count) file(s) in source folder"
        
        # --------------------------------------------------------------------------------
        # STEP 4.3: Determine current EST date for file matching
        # --------------------------------------------------------------------------------
        Write-Host "`n[INFO] Step 4.3: Calculating current EST date..."
        
        # Get Eastern Standard Time zone
        $estZone = [System.TimeZoneInfo]::FindSystemTimeZoneById("Eastern Standard Time")
        Write-Host "[DEBUG] Time zone: $($estZone.DisplayName)"
        
        # Convert current UTC time to EST and get date only (no time)
        $today = [System.TimeZoneInfo]::ConvertTimeFromUtc((Get-Date).ToUniversalTime(), $estZone).Date
        Write-Host "[INFO] Current EST date: $today"
        Write-Host "[DEBUG] Date format: $($today.ToString('yyyy-MM-dd'))"

        # --------------------------------------------------------------------------------
        # STEP 4.4: Search for today's HCM file
        # --------------------------------------------------------------------------------
        Write-Host "`n[INFO] Step 4.4: Searching for today's HCM file..."
        Write-Host "[DEBUG] Expected filename: $HCMFileName"
        Write-Host "[DEBUG] Expected modification date: $today"
        
        # Filter files by name and last write time matching today's date
        $hcmFile = $files | Where-Object {
            $_.Name -eq "$HCMFileName" -and
            $_.LastWriteTime.Date -eq $today
        }

        if ($hcmFile) {
            Write-Host "[SUCCESS] HCM file found for today!"
            Write-Host "[INFO] File details:"
            Write-Host "[INFO]   - Filename: $($hcmFile.Name)"
            Write-Host "[INFO]   - Size: $($hcmFile.Length) bytes"
            Write-Host "[INFO]   - Last Modified: $($hcmFile.LastWriteTime)"
            
            # --------------------------------------------------------------------------------
            # STEP 4.5: Generate backup filename with timestamp
            # --------------------------------------------------------------------------------
            Write-Host "`n[INFO] Step 4.5: Generating backup filename..."
            $timestamp = Get-Date -Format "yyyyMMddHHmmss"
            Write-Host "[DEBUG] Timestamp: $timestamp"
            
            $backupFileName = "$HCMFileName-$timestamp"
            Write-Host "[INFO] Backup filename: $backupFileName"
            
            # Define local file paths for download and backup
            $localFilePath = Join-Path $TempDir $HCMFileName
            $backupFilePath = Join-Path $TempDir $backupFileName
            Write-Host "[DEBUG] Local file path: $localFilePath"
            Write-Host "[DEBUG] Backup file path: $backupFilePath"

            # --------------------------------------------------------------------------------
            # STEP 4.6: Download file from SFTP
            # --------------------------------------------------------------------------------
            Write-Host "`n[INFO] Step 4.6: Downloading file from SFTP..."
            Get-SFTPItem -SessionId $SFTPSession.SessionId -Path "$HCMFolder/$HCMFileName" -Destination $TempDir
            Write-Host "[SUCCESS] Downloaded $HCMFileName to $localFilePath"
            Write-Host "[INFO] Local file size: $((Get-Item $localFilePath).Length) bytes"
            
            # --------------------------------------------------------------------------------
            # STEP 4.7: Rename file with timestamp for backup
            # --------------------------------------------------------------------------------
            Write-Host "`n[INFO] Step 4.7: Creating timestamped backup..."
            Rename-Item -Path $localFilePath -NewName $backupFileName
            Write-Host "[SUCCESS] File renamed to $backupFileName"

            # --------------------------------------------------------------------------------
            # STEP 4.8: Upload backup file to SFTP backup folder
            # --------------------------------------------------------------------------------
            Write-Host "`n[INFO] Step 4.8: Uploading backup to SFTP..."
            Write-Host "[DEBUG] Destination: $HCMbackupFolder/$backupFileName"
            Set-SFTPItem -SessionId $SFTPSession.SessionId -Path $backupFilePath -Destination "$HCMbackupFolder"
            Write-Host "[SUCCESS] Uploaded $backupFilePath to $HCMbackupFolder/$backupFileName"

            # --------------------------------------------------------------------------------
            # STEP 5: Load and validate HCM source configuration
            # --------------------------------------------------------------------------------
            Write-Host "`n================================================================================"
            Write-Host "[INFO] STEP 5: CONFIGURATION LOADING"
            Write-Host "================================================================================"
            
            Write-Host "[INFO] Loading HCM source configuration..."
            $sourceConfig = Get-SourceConfig -SourceName "HCM"
            
            # Validate the configuration structure
            Write-Host "[INFO] Validating configuration structure..."
            if (-not (Validate-SourceConfig -Config $sourceConfig)) {
                Write-Host "[ERROR] HCM source configuration validation failed"
                Write-Host "[ERROR] Cannot proceed with file processing"
                exit 1
            }
            
            Write-Host "[SUCCESS] Configuration loaded and validated"
            Write-Host "`n[INFO] Configuration Summary:"
            Write-Host "[INFO]   - Source Name: $($sourceConfig.SourceName)"
            Write-Host "[INFO]   - Expected Headers: $($sourceConfig.HeaderCount)"
            Write-Host "[INFO]   - Date Format: $($sourceConfig.DateFormat)"
            Write-Host "[INFO]   - Mandatory Fields: $($sourceConfig.MandatoryFields.Count)"
            Write-Host "[INFO]   - Process Validation Mode: $(if ($sourceConfig.processValidation) { 'STRICT' } else { 'NON-STRICT' })"
            Write-Host "[INFO]   - Termination Threshold: $($sourceConfig.LcsCalculationRules.TerminationThreshold)"

            # --------------------------------------------------------------------------------
            # STEP 6: Prepare email configuration
            # --------------------------------------------------------------------------------
            Write-Host "`n================================================================================"
            Write-Host "[INFO] STEP 6: EMAIL CONFIGURATION"
            Write-Host "================================================================================"
            
            Write-Host "[INFO] Building email configuration object..."
            $emailConfig = @{
                FromAddress = $emailFrom
                ToAddress = $HCMemailToArray
                CcAddress = $sailpointTeamCCArray
                SmtpServer = $smtpServer
                Subject = "SailPoint - HCM HR File Validation $today"
            }
            
            Write-Host "[SUCCESS] Email configuration prepared"
            Write-Host "[INFO] Email Configuration:"
            Write-Host "[INFO]   - From: $($emailConfig.FromAddress)"
            Write-Host "[INFO]   - To: $($emailConfig.ToAddress -join ', ')"
            Write-Host "[INFO]   - CC: $($emailConfig.CcAddress -join ', ')"
            Write-Host "[INFO]   - SMTP Server: $($emailConfig.SmtpServer)"
            Write-Host "[INFO]   - Subject: $($emailConfig.Subject)"

            # --------------------------------------------------------------------------------
            # STEP 7: Execute validation process
            # --------------------------------------------------------------------------------
            Write-Host "`n================================================================================"
            Write-Host "[INFO] STEP 7: EXECUTING VALIDATION PROCESS"
            Write-Host "================================================================================"
            
            Write-Host "[INFO] Calling Start-Validation function..."
            Write-Host "[DEBUG] Backup file path: $($backupFilePath.Trim())"
            Write-Host "[DEBUG] Backup folder: $HCMBackupFolder"
            Write-Host "[DEBUG] Source folder: $HCMFolder"
            
            $validationResult = Start-Validation `
                -SourceConfig $sourceConfig `
                -BackupFilePath $backupFilePath.Trim() `
                -EmailConfig $emailConfig `
                -BackupFolder $HCMBackupFolder `
                -SourceFolder $HCMFolder `
                -Password $password `
                -SftpUser $sftpUser `
                -SftpHost $sftpHost
            
            Write-Host "[INFO] Validation process completed with exit code: $validationResult"
            
            # --------------------------------------------------------------------------------
            # STEP 8: Process validation results
            # --------------------------------------------------------------------------------
            Write-Host "`n================================================================================"
            Write-Host "[INFO] STEP 8: PROCESSING VALIDATION RESULTS"
            Write-Host "================================================================================"
            
            if ($validationResult -eq 0) {
                Write-Host "[SUCCESS] =========================================="
                Write-Host "[SUCCESS] HCM VALIDATION COMPLETED SUCCESSFULLY"
                Write-Host "[SUCCESS] =========================================="
                Write-Host "[SUCCESS] File has been validated and processed"
                Write-Host "[SUCCESS] File has been backed up successfully"
                Write-Host "[SUCCESS] All validation checks passed"
            } else {
                Write-Host "[WARNING] =========================================="
                Write-Host "[WARNING] HCM VALIDATION COMPLETED WITH ISSUES"
                Write-Host "[WARNING] =========================================="
                Write-Host "[WARNING] Exit Code: $validationResult"
                Write-Host "[WARNING] Check email reports for detailed information"
                Write-Host "[WARNING] Review logs above for specific validation failures"
            }

            # --------------------------------------------------------------------------------
            # STEP 9: Final summary and exit
            # --------------------------------------------------------------------------------
            Write-Host "`n================================================================================"
            Write-Host "[INFO] FINAL SUMMARY"
            Write-Host "================================================================================"
            Write-Host "[INFO] Script completed at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
            Write-Host "[INFO] Processing result: $(if ($validationResult -eq 0) { 'SUCCESS' } else { 'COMPLETED WITH ISSUES' })"
            Write-Host "[INFO] Exit code: $validationResult"
            Write-Host "[INFO] Backup location: $HCMbackupFolder/$backupFileName"
            Write-Host "================================================================================"
            
            exit $validationResult
            
        } else {
            # --------------------------------------------------------------------------------
            # FILE NOT FOUND HANDLING
            # --------------------------------------------------------------------------------
            Write-Host "`n[WARNING] =========================================="
            Write-Host "[WARNING] FILE NOT FOUND"
            Write-Host "[WARNING] =========================================="
            Write-Host "[WARNING] $HCMFileName was not received today"
            Write-Host "[WARNING] Expected location: $HCMFolder/$HCMFileName"
            Write-Host "[WARNING] Expected modification date: $today"
            Write-Host "[WARNING] Files found in directory: $($files.Count)"
            
            if ($files.Count -gt 0) {
                Write-Host "`n[INFO] Files present in source folder:"
                foreach ($file in $files) {
                    Write-Host "[INFO]   - $($file.Name) (Modified: $($file.LastWriteTime))"
                }
            }

            # --------------------------------------------------------------------------------
            # SEND FILE MISSING NOTIFICATION EMAIL
            # --------------------------------------------------------------------------------
            Write-Host "`n[INFO] Preparing file missing notification email..."
            
            $subject = "SailPoint - HCM HR File Missing Notification - $today"
            Write-Host "[DEBUG] Email subject: $subject"
            
            # Build HTML email body
            $body = @"
<html>
<body>
<h2>HCM HR File Missing Notification</h2>
<p><strong>Hello Team,</strong></p>
<p>This is a notification that the HCM HR file <strong>$HCMFileName</strong> was not received on <strong>$today</strong>.</p>

<h3>Details:</h3>
<ul>
    <li><strong>Expected File:</strong> $HCMFileName</li>
    <li><strong>Expected Location:</strong> $HCMFolder</li>
    <li><strong>Expected Date:</strong> $today</li>
    <li><strong>Check Time:</strong> $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</li>
</ul>

<h3>Next Steps:</h3>
<ol>
    <li>Please verify the file has been generated by the source system</li>
    <li>Upload the file to the shared location at your earliest convenience</li>
    <li>Contact the SailPoint team if you need assistance</li>
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
            Write-Host "[INFO] Sending file missing notification email..."
            try {
                Send-MailMessage -From $emailFrom `
                    -To $HCMemailToArray `
                    -Cc $sailpointTeamCCArray `
                    -Subject $subject `
                    -Body $body `
                    -BodyAsHtml `
                    -SmtpServer $smtpServer
                
                Write-Host "[SUCCESS] File missing notification sent successfully"
                Write-Host "[INFO] Email sent to: $($HCMemailToArray -join ', ')"
                Write-Host "[INFO] Email CC to: $($sailpointTeamCCArray -join ', ')"
            } catch {
                Write-Host "[ERROR] Failed to send file missing notification: $_"
                Write-Host "[ERROR] Stack trace: $($_.ScriptStackTrace)"
            }

            Write-Host "`n================================================================================"
            Write-Host "[INFO] HCM PROCESSING COMPLETED - FILE NOT FOUND"
            Write-Host "================================================================================"
            Write-Host "[INFO] This is not an error - the file has simply not been received yet"
            Write-Host "[INFO] The process will run again at the next scheduled time"
            Write-Host "[INFO] Exit code: 0 (normal completion)"
            Write-Host "================================================================================"
            
            exit 0  # Not an error - just file not received yet
        }
    }
    catch {
        # --------------------------------------------------------------------------------
        # CRITICAL ERROR HANDLING
        # --------------------------------------------------------------------------------
        Write-Host "`n[ERROR] =========================================="
        Write-Host "[ERROR] CRITICAL ERROR IN HCM PROCESSING"
        Write-Host "[ERROR] =========================================="
        Write-Host "[ERROR] Exception Details:"
        Write-Host "[ERROR] Message: $_"
        Write-Host "[ERROR] Stack Trace: $($_.ScriptStackTrace)"
        Write-Host "[ERROR] Line Number: $($_.InvocationInfo.ScriptLineNumber)"
        Write-Host "[ERROR] Command: $($_.InvocationInfo.MyCommand)"
        Write-Host "[ERROR] =========================================="
        
        # Send error notification email
        Write-Host "`n[INFO] Attempting to send error notification email..."
        try {
            $errorSubject = "SailPoint - HCM Processing Error - $today"
            $errorBody = @"
<html>
<body>
<h2 style="color: red;">HCM Processing Critical Error</h2>
<p><strong>Critical Error Occurred During HCM File Processing</strong></p>

<h3>Error Details:</h3>
<pre style="background-color: #f5f5f5; padding: 10px; border: 1px solid #ddd;">
$_
</pre>

<h3>Additional Information:</h3>
<ul>
    <li><strong>Time:</strong> $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</li>
    <li><strong>File:</strong> $HCMFileName</li>
    <li><strong>Source Folder:</strong> $HCMFolder</li>
    <li><strong>SFTP Host:</strong> $sftpHost</li>
</ul>

<h3>Next Steps:</h3>
<ol>
    <li>Review the error message and stack trace above</li>
    <li>Check SFTP connectivity and credentials</li>
    <li>Verify file permissions and folder access</li>
    <li>Review application logs for additional details</li>
    <li>Contact the development team if the issue persists</li>
</ol>

<p><strong>URGENT:</strong> Please investigate and resolve this issue immediately.</p>
<br>
<p><em>Automated HR File Validation System</em><br>
<em>Cybersecurity Team</em></p>
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
            
            Write-Host "[SUCCESS] Error notification email sent successfully"
        } catch {
            Write-Host "[ERROR] Failed to send error notification email: $_"
            Write-Host "[ERROR] Manual intervention required - check logs"
        }
        
        Write-Host "`n================================================================================"
        Write-Host "[ERROR] HCM PROCESSING TERMINATED DUE TO CRITICAL ERROR"
        Write-Host "[INFO] Exit code: 1 (error)"
        Write-Host "================================================================================"
        
        exit 1
    }
}

# ================================================================================
# SCRIPT ENTRY POINT
# PURPOSE: Parse command-line arguments and invoke main processing function
# USAGE: Called from Azure DevOps pipeline with 9 arguments
# ================================================================================
Write-Host "`n================================================================================"
Write-Host "[INFO] PARSING COMMAND-LINE ARGUMENTS"
Write-Host "================================================================================"

Write-Host "[INFO] Number of arguments received: $($args.Count)"
Write-Host "[DEBUG] Argument 1 (password): <hidden for security>"
Write-Host "[DEBUG] Argument 2 (sftpUser): $($args[1])"
Write-Host "[DEBUG] Argument 3 (sftpHost): $($args[2])"
Write-Host "[DEBUG] Argument 4 (HCMFolder): $($args[3])"
Write-Host "[DEBUG] Argument 5 (HCMbackupFolder): $($args[4])"
Write-Host "[DEBUG] Argument 6 (HCMFileName): $($args[5])"
Write-Host "[DEBUG] Argument 7 (emailFrom): $($args[6])"
Write-Host "[DEBUG] Argument 8 (HCMemailTo): $($args[7])"
Write-Host "[DEBUG] Argument 9 (sailpointTeamCC): $($args[8])"

# Validate minimum required arguments
if ($args.Count -lt 9) {
    Write-Host "[ERROR] Insufficient arguments provided"
    Write-Host "[ERROR] Expected 9 arguments, received $($args.Count)"
    Write-Host "[ERROR] Usage: HCM.ps1 <password> <sftpUser> <sftpHost> <HCMFolder> <HCMbackupFolder> <HCMFileName> <emailFrom> <HCMemailTo> <sailpointTeamCC>"
    exit 1
}

Write-Host "[SUCCESS] All required arguments received"

# Invoke main processing function with parsed arguments
Write-Host "`n[INFO] Invoking HCM file mover function..."
Run-HCM-FileMover `
    -password $args[0] `
    -sftpUser $args[1] `
    -sftpHost $args[2] `
    -HCMFolder $args[3] `
    -HCMbackupFolder $args[4] `
    -HCMFileName $args[5] `
    -emailFrom $args[6] `
    -HCMemailTo $args[7] `
    -sailpointTeamCC $args[8]
