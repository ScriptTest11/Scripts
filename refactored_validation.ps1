
Import-Module -Name "" -Force

function Start-Validation {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [hashtable]$SourceConfig,
        
        [Parameter(Mandatory=$true)]
        [string]$BackupFilePath,
        
        [Parameter(Mandatory=$true)]
        [hashtable]$EmailConfig,
        
        [Parameter(Mandatory=$true)]
        [string]$BackupFolder,   

        [Parameter(Mandatory=$true)]
        [string]$SourceFolder,   

        [Parameter(Mandatory=$true)]
        [string]$SftpUser,

        [Parameter(Mandatory=$true)]
        [string]$Password,

        [Parameter(Mandatory=$true)]
        [string]$SftpHost
    )

    # ================================================================================
    # SETUP SECTION: Initialize environment, sessions, and working directories
    # ================================================================================
    Write-Host "================================================================================"
    Write-Host "[INFO] VALIDATION PROCESS INITIATED"
    Write-Host "================================================================================"
    
    # Generate timestamp for file naming and reporting
    $todayStr = Get-Date -Format "yyyy-MM-dd"
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[INFO] Process started at: $timestamp"
    Write-Host "[INFO] Date identifier: $todayStr"

    # --------------------------------------------------------------------------------
    # Establish SFTP connection
    # --------------------------------------------------------------------------------
    Write-Host "`n[INFO] Establishing SFTP connection..."
    Write-Host "[DEBUG] SFTP Host: $SftpHost"
    Write-Host "[DEBUG] SFTP User: $SftpUser"
    
    $SecurePass = ConvertTo-SecureString $Password -AsPlainText -Force
    $Credential = New-Object System.Management.Automation.PSCredential ($SftpUser, $SecurePass)
    
    try {
        $SFTPSession = New-SFTPSession -ComputerName $SftpHost -Credential $Credential -AcceptKey -Verbose
        Write-Host "[SUCCESS] SFTP session established to $SftpHost (Session ID: $($SFTPSession.SessionId))"
    } catch {
        Write-Host "[ERROR] Failed to establish SFTP connection: $_"
        return 1
    }

    # --------------------------------------------------------------------------------
    # Setup temporary directory for local file staging
    # --------------------------------------------------------------------------------
    Write-Host "`n[INFO] Setting up temporary directory for file operations..."
    $TempDir = Join-Path $env:TEMP "SFTPTemp"
    Write-Host "[DEBUG] Temporary directory path: $TempDir"
    
    if (!(Test-Path -Path $TempDir)) {
        Write-Host "[INFO] Creating temporary directory..."
        New-Item -Path $TempDir -ItemType Directory -Force | Out-Null
        Write-Host "[SUCCESS] Temporary directory created"
    } else {
        Write-Host "[INFO] Temporary directory already exists"
    }

    # --------------------------------------------------------------------------------
    # Define remote report directory on SFTP
    # --------------------------------------------------------------------------------
    $ReportRemoteDir = (Join-Path $BackupFolder "/report")
    Write-Host "[INFO] Remote report directory: $ReportRemoteDir"

    function Normalize-RemotePath([string]$PathText) {
        $normalized = ($PathText -replace '\\','/').Trim()
        Write-Host "[DEBUG] Path normalized: $PathText -> $normalized"
        return $normalized
    }

    # --------------------------------------------------------------------------------
    # FUNCTION: replace-processingFile
    # PURPOSE: Download source file and upload to processing folder (with replacement)
    # --------------------------------------------------------------------------------
    function replace-processingFile (
        [string]$sourceRemotePath, 
        [string]$TempDir, 
        [string]$tempSourceLocalPath, 
        [string]$processingRemoteDir, 
        [string]$SourceFileName
    ) {
        Write-Host "`n[INFO] Starting file replacement process..."
        Write-Host "[DEBUG] Source remote path: $sourceRemotePath"
        Write-Host "[DEBUG] Temp directory: $TempDir"
        Write-Host "[DEBUG] Local temp path: $tempSourceLocalPath"
        Write-Host "[DEBUG] Processing remote directory: $processingRemoteDir"
        Write-Host "[DEBUG] Source filename: $SourceFileName"
        
        try {
            # Create new SFTP session for file operations
            Write-Host "[INFO] Creating SFTP session for file operations..."
            $HRSFTPSession = New-SFTPSession -ComputerName $SftpHost -Credential $Credential -AcceptKey -Verbose
            Write-Host "[SUCCESS] SFTP session created (Session ID: $($HRSFTPSession.SessionId))"
            
            # Normalize remote directory path
            $remoteDir = ($processingRemoteDir -replace '\\','/').TrimEnd('/')
            Write-Host "[INFO] Normalized remote directory: $remoteDir"

            # Download source file from SFTP
            Write-Host "[INFO] Downloading file from SFTP..."
            Get-SFTPItem -SessionId $HRSFTPSession.SessionId -Path $sourceRemotePath -Destination $TempDir
            Write-Host "[SUCCESS] Downloaded $SourceFileName to $TempDir"
            
            # Construct final remote file path
            $finalHrFile = "$remoteDir/$SourceFileName"
            Write-Host "[DEBUG] Final remote file path: $finalHrFile"

            # Check if file already exists on SFTP and remove if present
            Write-Host "[INFO] Checking if remote file already exists..."
            $existing = Test-SFTPPath -SessionId $HRSFTPSession.SessionId -Path $finalHrFile -ErrorAction SilentlyContinue
            
            if ($existing) {
                Write-Host "[WARNING] Remote file exists - removing before upload: $finalHrFile"
                Remove-SFTPItem -SessionId $HRSFTPSession.SessionId -Path $finalHrFile -Force -ErrorAction Stop
                Write-Host "[SUCCESS] Existing file removed"
            } else {
                Write-Host "[INFO] No existing file found - proceeding with upload"
            }
            
            # Upload file to processing directory
            Write-Host "[INFO] Uploading file to processing directory..."
            Set-SFTPItem -SessionId $HRSFTPSession.SessionId -Path $tempSourceLocalPath -Destination $processingRemoteDir
            Write-Host "[SUCCESS] Uploaded $tempSourceLocalPath to $processingRemoteDir"
            
        } catch {
            Write-Host "[ERROR] Exception occurred while replacing main HR file: $_"
            Write-Host "[ERROR] Stack trace: $($_.ScriptStackTrace)"
            return 1
        }
    }

    # --------------------------------------------------------------------------------
    # FUNCTION: Upload-Replace
    # PURPOSE: Upload local file to SFTP, replacing if exists
    # --------------------------------------------------------------------------------
    function Upload-Replace(
        [string]$LocalFilePath, 
        [string]$RemoteDir, 
        [string]$RemoteFileName
    ) {
        Write-Host "`n[INFO] Uploading file with replacement..."
        Write-Host "[DEBUG] Local file path: $LocalFilePath"
        Write-Host "[DEBUG] Remote directory: $RemoteDir"
        Write-Host "[DEBUG] Remote filename: $RemoteFileName"
        
        try {
            # Normalize remote directory path
            $remoteDir = ($RemoteDir -replace '\\','/').TrimEnd('/')
            Write-Host "[DEBUG] Normalized remote directory: $remoteDir"

            # Construct full remote file path
            $remoteFile = "$remoteDir/$RemoteFileName"
            Write-Host "[DEBUG] Full remote file path: $remoteFile"

            # Check if remote file already exists
            Write-Host "[INFO] Checking for existing remote file..."
            $existing = Test-SFTPPath -SessionId $SFTPSession.SessionId -Path $remoteFile -ErrorAction SilentlyContinue
            
            if ($existing) {
                Write-Host "[WARNING] Remote file exists - removing before upload: $remoteFile"
                Remove-SFTPItem -SessionId $SFTPSession.SessionId -Path $remoteFile -Force -ErrorAction Stop
                Write-Host "[SUCCESS] Existing remote file removed"
            } else {
                Write-Host "[INFO] No existing file found"
            }

            # Upload file to SFTP
            Write-Host "[INFO] Uploading file to SFTP..."
            Set-SFTPItem -SessionId $SFTPSession.SessionId `
                -Path $LocalFilePath `
                -Destination $remoteDir `
                -ErrorAction Stop
            Write-Host "[SUCCESS] File uploaded to: $remoteFile"
            
        } catch {
            Write-Host "[ERROR] Failed to upload file to '$remoteDir': $_"
            Write-Host "[ERROR] Stack trace: $($_.ScriptStackTrace)"
        }
    }

    # ================================================================================
    # VALIDATION OVERVIEW
    # ================================================================================
    Write-Host "`n================================================================================"
    Write-Host "[INFO] VALIDATION CONFIGURATION"
    Write-Host "================================================================================"
    Write-Host "[INFO] Source Name: $($SourceConfig.SourceName)"
    Write-Host "[INFO] Processing File: $BackupFilePath"
    Write-Host "[INFO] Process Validation Mode: $($SourceConfig.processValidation)"
    Write-Host "[INFO] Expected Header Count: $($SourceConfig.HeaderCount)"
    Write-Host "[INFO] Date Format: $($SourceConfig.DateFormat)"
    Write-Host "[INFO] Mandatory Fields Count: $($SourceConfig.MandatoryFields.Count)"
    Write-Host "================================================================================"

    # --------------------------------------------------------------------------------
    # Validate CSV file exists locally
    # --------------------------------------------------------------------------------
    Write-Host "`n[INFO] Validating CSV file existence..."
    if (-not (Test-Path -Path $BackupFilePath)) {
        Write-Host "[ERROR] CSV file not found at path: $BackupFilePath"
        Write-Host "[ERROR] Aborting validation process"
        Remove-SFTPSession -SessionId $SFTPSession.SessionId
        return 1
    }
    Write-Host "[SUCCESS] CSV file found and accessible"

    # --------------------------------------------------------------------------------
    # Import CSV data with source-specific filtering
    # --------------------------------------------------------------------------------
    Write-Host "`n[INFO] Importing CSV data..."
    try {
        if ($SourceConfig.SourceName -eq "HCM") {
            Write-Host "[INFO] Applying HCM-specific filters (Country=US, excluding specific employee numbers)..."
            
            $employees = Import-Csv -Path $BackupFilePath -ErrorAction Stop | Where-Object {
                $_.COUNTRY -eq 'US' -and
                $_.EMPLOYEENUMBER -notin @(
                    '125248401090', '125248401167', '124242402061', '125248401052',
                    '700008166', '700005909', '124909006603', '125242411110',
                    '124353502270', '125242400425', '125242411249'
                )
            }
            Write-Host "[INFO] HCM filters applied - excluded employee count: 11"
        } else {
            Write-Host "[INFO] No source-specific filters applied"
            $employees = Import-Csv -Path $BackupFilePath -ErrorAction Stop
        }
        Write-Host "[SUCCESS] Successfully imported $($employees.Count) employee records"
    } catch {
        Write-Host "[ERROR] Failed to import CSV file: $_"
        Write-Host "[ERROR] Stack trace: $($_.ScriptStackTrace)"
        Remove-SFTPSession -SessionId $SFTPSession.SessionId
        return 1
    }

    # ================================================================================
    # STEP 1: HEADER VALIDATION (FAIL-FAST)
    # ================================================================================
    Write-Host "`n================================================================================"
    Write-Host "[STEP 1] HEADER VALIDATION"
    Write-Host "================================================================================"

    Write-Host "[INFO] Reading CSV header line..."
    $headerLine = Get-Content -Path $BackupFilePath -TotalCount 1
    $headerColumns = $headerLine -split ','
    Write-Host "[DEBUG] Header columns found: $($headerColumns.Count)"
    Write-Host "[DEBUG] Expected columns: $($SourceConfig.HeaderCount)"

    # Validate header column count
    Write-Host "`n[INFO] Validating header column count..."
    if ($headerColumns.Count -ne $SourceConfig.HeaderCount) {
        Write-Host "[ERROR] HEADER COUNT MISMATCH!"
        Write-Host "[ERROR] Expected: $($SourceConfig.HeaderCount)"
        Write-Host "[ERROR] Found: $($headerColumns.Count)"
        
        $bodyMessage = "Header Count mismatch for $($SourceConfig.SourceName).`nExpected: $($SourceConfig.HeaderCount)`nFound: $($headerColumns.Count)`n`nPlease verify the file format and try again."
        
        Write-Host "[INFO] Sending email notification for header count mismatch..."
        Send-ValidationEmail -EmailConfig $EmailConfig -Subject "$($EmailConfig.Subject) - Header Count Mismatch" -Body $bodyMessage
        Write-Host "[INFO] Email notification sent"
        
        Write-Host "[ERROR] Header validation FAILED - stopping process"
        Remove-SFTPSession -SessionId $SFTPSession.SessionId
        return 1
    }
    Write-Host "[SUCCESS] Header count validation passed"

    # Validate required header fields are present
    Write-Host "`n[INFO] Validating required header fields..."
    Write-Host "[DEBUG] Checking for $($SourceConfig.HeaderFields.Count) required fields..."
    
    foreach ($requiredHeader in $SourceConfig.HeaderFields) {
        if ($headerColumns -notcontains $requiredHeader) {
            Write-Host "[ERROR] MISSING REQUIRED HEADER FIELD: $requiredHeader"
            
            $bodyMessage = "Missing required header field '$requiredHeader' for $($SourceConfig.SourceName).`n`nRequired headers: $($SourceConfig.HeaderFields -join ', ')`n`nPlease verify the file format and try again."
            
            Write-Host "[INFO] Sending email notification for missing header field..."
            Send-ValidationEmail -EmailConfig $EmailConfig -Subject "$($EmailConfig.Subject) - Missing Header Field" -Body $bodyMessage
            Write-Host "[INFO] Email notification sent"
            
            Write-Host "[ERROR] Header field validation FAILED - stopping process"
            Remove-SFTPSession -SessionId $SFTPSession.SessionId
            return 1
        }
    }
    Write-Host "[SUCCESS] All required header fields present"
    Write-Host "[SUCCESS] Step 1: Header validation PASSED"

    # ================================================================================
    # STEP 2: DATE VALIDATION (FAIL-FAST)
    # ================================================================================
    Write-Host "`n================================================================================"
    Write-Host "[STEP 2] DATE VALIDATION"
    Write-Host "================================================================================"

    Write-Host "[INFO] Initializing date validation..."
    $inputFormat = $SourceConfig.DateFormat
    Write-Host "[DEBUG] Expected date format: $inputFormat"
    
    # Initialize tracking arrays for date validation issues
    $invalidHireDateList = @()
    $missingHireDateList = @()
    $invalidTerminationDateList = @()
    
    # Get field names from configuration
    $hireDate = $SourceConfig.HireDate
    $termDate = $SourceConfig.TermDate
    Write-Host "[DEBUG] Hire date field: $hireDate"
    Write-Host "[DEBUG] Termination date field: $termDate"

    Write-Host "`n[INFO] Validating dates for $($employees.Count) employees..."
    $validationProgress = 0
    
    foreach ($employee in $employees) {
        $employeeNumber = $employee.EMPLOYEENUMBER
        $validationProgress++
        
        # Log progress every 100 employees
        if ($validationProgress % 100 -eq 0) {
            Write-Host "[PROGRESS] Validated dates for $validationProgress / $($employees.Count) employees..."
        }

        # --------------------------------------------------------------------------------
        # Validate hire date field
        # --------------------------------------------------------------------------------
        if (![string]::IsNullOrWhiteSpace($employee.$hireDate)) {
            try {
                # Attempt to parse hire date
                [DateTime]::ParseExact($employee.$hireDate, $inputFormat, $null) | Out-Null
            } catch {
                # Add to invalid list if parsing fails
                $invalidHireDateList += $employee
                Write-Host "[ERROR] Invalid hire date format for employee $employeeNumber : $($employee.$hireDate)"
            }
        } else {
            # Add to missing list if hire date is empty
            $missingHireDateList += $employee
            Write-Host "[WARNING] Missing hire date for employee $employeeNumber"
        }

        # --------------------------------------------------------------------------------
        # Validate termination date field (if present)
        # --------------------------------------------------------------------------------
        if (![string]::IsNullOrWhiteSpace($employee.$termDate)) {
            try {
                # Attempt to parse termination date
                [DateTime]::ParseExact($employee.$termDate, $inputFormat, $null) | Out-Null
            } catch {
                # Add to invalid list if parsing fails
                $invalidTerminationDateList += $employee
                Write-Host "[ERROR] Invalid termination date format for employee $employeeNumber : $($employee.$termDate)"
            }
        }
    }

    Write-Host "[INFO] Date validation complete"
    Write-Host "[SUMMARY] Invalid hire dates: $($invalidHireDateList.Count)"
    Write-Host "[SUMMARY] Missing hire dates: $($missingHireDateList.Count)"
    Write-Host "[SUMMARY] Invalid termination dates: $($invalidTerminationDateList.Count)"

    # --------------------------------------------------------------------------------
    # Handle invalid hire dates
    # --------------------------------------------------------------------------------
    if ($invalidHireDateList.Count -gt 0) {
        Write-Host "`n[ERROR] INVALID HIRE DATES DETECTED - $($invalidHireDateList.Count) employees"
        
        $localCsv = Join-Path $TempDir "invalid_hire_dates_$($SourceConfig.SourceName)_$todayStr.csv"
        Write-Host "[INFO] Generating invalid hire dates report: $localCsv"
        $invalidHireDateList | Export-Csv -Path $localCsv -NoTypeInformation -Encoding UTF8
        Write-Host "[SUCCESS] Report generated locally"
        
        Write-Host "[INFO] Uploading report to SFTP..."
        Upload-Replace -LocalFilePath $localCsv -RemoteDir $ReportRemoteDir -RemoteFileName (Split-Path $localCsv -Leaf)
        Write-Host "[SUCCESS] Report uploaded to SFTP"

        $bodyMessage = "Found $($invalidHireDateList.Count) employees with invalid hire dates for $($SourceConfig.SourceName).`nExpected format: $($SourceConfig.DateFormat)`n`nPlease fix the dates and resubmit the file."
        
        Write-Host "[INFO] Sending email notification..."
        Send-ValidationEmail -EmailConfig $EmailConfig -Subject "$($EmailConfig.Subject) - Invalid Hire Dates" -Body $bodyMessage -AttachmentPath $localCsv
        Write-Host "[INFO] Email notification sent with attachment"

        Write-Host "[ERROR] Date validation FAILED - stopping process"
        Remove-SFTPSession -SessionId $SFTPSession.SessionId
        return 1
    }

    # --------------------------------------------------------------------------------
    # Handle missing hire dates
    # --------------------------------------------------------------------------------
    if ($missingHireDateList.Count -gt 0) {
        Write-Host "`n[ERROR] MISSING HIRE DATES DETECTED - $($missingHireDateList.Count) employees"
        
        $localCsv = Join-Path $TempDir "missing_hire_dates_$($SourceConfig.SourceName)_$todayStr.csv"
        Write-Host "[INFO] Generating missing hire dates report: $localCsv"
        $missingHireDateList | Export-Csv -Path $localCsv -NoTypeInformation -Encoding UTF8
        Write-Host "[SUCCESS] Report generated locally"
        
        Write-Host "[INFO] Uploading report to SFTP..."
        Upload-Replace -LocalFilePath $localCsv -RemoteDir $ReportRemoteDir -RemoteFileName (Split-Path $localCsv -Leaf)
        Write-Host "[SUCCESS] Report uploaded to SFTP"

        $bodyMessage = "Found $($missingHireDateList.Count) employees with missing hire dates for $($SourceConfig.SourceName).`n`nPlease provide hire dates for all employees and resubmit the file."
        
        Write-Host "[INFO] Sending email notification..."
        Send-ValidationEmail -EmailConfig $EmailConfig -Subject "$($EmailConfig.Subject) - Missing Hire Dates" -Body $bodyMessage -AttachmentPath $localCsv
        Write-Host "[INFO] Email notification sent with attachment"

        Write-Host "[ERROR] Date validation FAILED - stopping process"
        Remove-SFTPSession -SessionId $SFTPSession.SessionId
        return 1
    }

    # --------------------------------------------------------------------------------
    # Handle invalid termination dates
    # --------------------------------------------------------------------------------
    if ($invalidTerminationDateList.Count -gt 0) {
        Write-Host "`n[ERROR] INVALID TERMINATION DATES DETECTED - $($invalidTerminationDateList.Count) employees"
        
        $localCsv = Join-Path $TempDir "invalid_termination_dates_$($SourceConfig.SourceName)_$todayStr.csv"
        Write-Host "[INFO] Generating invalid termination dates report: $localCsv"
        $invalidTerminationDateList | Export-Csv -Path $localCsv -NoTypeInformation -Encoding UTF8
        Write-Host "[SUCCESS] Report generated locally"
        
        Write-Host "[INFO] Uploading report to SFTP..."
        Upload-Replace -LocalFilePath $localCsv -RemoteDir $ReportRemoteDir -RemoteFileName (Split-Path $localCsv -Leaf)
        Write-Host "[SUCCESS] Report uploaded to SFTP"

        $bodyMessage = "Found $($invalidTerminationDateList.Count) employees with invalid termination dates for $($SourceConfig.SourceName).`nExpected format: $($SourceConfig.DateFormat)`n`nPlease fix the dates and resubmit the file."
        
        Write-Host "[INFO] Sending email notification..."
        Send-ValidationEmail -EmailConfig $EmailConfig -Subject "$($EmailConfig.Subject) - Invalid Termination Dates" -Body $bodyMessage -AttachmentPath $localCsv
        Write-Host "[INFO] Email notification sent with attachment"

        Write-Host "[ERROR] Date validation FAILED - stopping process"
        Remove-SFTPSession -SessionId $SFTPSession.SessionId
        return 1
    }

    Write-Host "[SUCCESS] Step 2: Date validation PASSED - All dates are valid"

    # ================================================================================
    # STEP 3: EMPLOYEE STATUS CALCULATION
    # ================================================================================
    Write-Host "`n================================================================================"
    Write-Host "[STEP 3] EMPLOYEE STATUS CALCULATION"
    Write-Host "================================================================================"

    Write-Host "[INFO] Initializing status calculation..."
    $lcsRules = $SourceConfig.LcsCalculationRules
    Write-Host "[DEBUG] Lifecycle calculation rules loaded"
    Write-Host "[DEBUG] Pre-hire days threshold: $($lcsRules.PreHireDays)"
    Write-Host "[DEBUG] Termination spike threshold: $($lcsRules.TerminationThreshold)"
    
    # Initialize status counter
    $statusCounts = @{}
    
    Write-Host "`n[INFO] Calculating status for $($employees.Count) employees..."
    $calculationProgress = 0

    foreach ($employee in $employees) {
        $calculationProgress++
        
        # Log progress every 100 employees
        if ($calculationProgress % 100 -eq 0) {
            Write-Host "[PROGRESS] Calculated status for $calculationProgress / $($employees.Count) employees..."
        }
        
        # Validate parameters before calling status calculation
        if ($null -eq $SourceConfig) { 
            Write-Host "[ERROR] SourceConfig is null - cannot proceed"
            Write-Error "SourceConfig is null."
            return 1
        }
        if ($null -eq $employee) { 
            Write-Host "[ERROR] Employee object is null - skipping"
            Write-Error "Employee object is null."
            return 1
        }
        if ($null -eq $lcsRules) { 
            Write-Host "[ERROR] LcsRules is null - cannot proceed"
            Write-Error "LcsRules is null."
            return 1
        }

        # Call status calculation function
        $status = Get-EmployeeStatusBySource -SourceName $SourceConfig.SourceName -Employee $employee -LcsRules $lcsRules

        # Update status counter
        if ($statusCounts.ContainsKey($status)) {
            $statusCounts[$status] += 1
        } else {
            $statusCounts[$status] = 1
        }
    }

    Write-Host "[SUCCESS] Status calculation completed"
    Write-Host "[SUMMARY] Status distribution:"
    foreach ($status in $statusCounts.Keys | Sort-Object) {
        Write-Host "[SUMMARY]   - $status : $($statusCounts[$status]) employees"
    }

    # ================================================================================
    # STEP 4: SAVE STATUS REPORT TO SFTP
    # ================================================================================
    Write-Host "`n================================================================================"
    Write-Host "[STEP 4] GENERATE AND SAVE STATUS REPORT"
    Write-Host "================================================================================"

    Write-Host "[INFO] Preparing status report data..."
    $localJson = Join-Path $TempDir "status_count_$($SourceConfig.SourceName)_$todayStr.json"
    Write-Host "[DEBUG] Local JSON path: $localJson"
    
    # Build status report object
    $statusReport = @{
        Date = $todayStr
        SourceName = $SourceConfig.SourceName
        TotalEmployees = $employees.Count
        StatusCounts = $statusCounts
        ProcessedAt = $timestamp
    }
    
    Write-Host "[INFO] Status report structure:"
    Write-Host "[INFO]   - Date: $todayStr"
    Write-Host "[INFO]   - Source: $($SourceConfig.SourceName)"
    Write-Host "[INFO]   - Total Employees: $($employees.Count)"
    Write-Host "[INFO]   - Processed At: $timestamp"

    Write-Host "`n[INFO] Writing status report to local JSON file..."
    $statusReport | ConvertTo-Json -Depth 5 | Out-File -FilePath $localJson -Encoding UTF8
    Write-Host "[SUCCESS] JSON file created locally"
    
    Write-Host "[INFO] Uploading status report to SFTP..."
    Upload-Replace -LocalFilePath $localJson -RemoteDir $ReportRemoteDir -RemoteFileName (Split-Path $localJson -Leaf)
    Write-Host "[SUCCESS] Status report uploaded to SFTP: $ReportRemoteDir"

    # ================================================================================
    # STEP 5: TERMINATION SPIKE DETECTION
    # ================================================================================
    Write-Host "`n================================================================================"
    Write-Host "[STEP 5] TERMINATION SPIKE DETECTION"
    Write-Host "================================================================================"

    Write-Host "[INFO] Determining comparison date based on day of week..."
    $todayDT = Get-Date
    Write-Host "[DEBUG] Today's date: $todayDT"
    Write-Host "[DEBUG] Day of week: $($todayDT.DayOfWeek)"

    # Determine target date based on day of week
    if ($todayDT.DayOfWeek -eq 'Monday') {
        # On Monday, compare with Friday (2 days ago)
        $targetDate = $todayDT.AddDays(-2).ToString("yyyy-MM-dd")
        Write-Host "[INFO] Today is Monday - comparing with Friday"
    } else {
        # On other days, compare with yesterday (1 day ago)
        $targetDate = $todayDT.AddDays(-1).ToString("yyyy-MM-dd")
        Write-Host "[INFO] Comparing with yesterday"
    }
    Write-Host "[INFO] Target comparison date: $targetDate"

    # Construct path to yesterday's status report
    $yesterdayRemoteJson = Join-Path $ReportRemoteDir "status_count_$($SourceConfig.SourceName)_$targetDate.json"
    Write-Host "[DEBUG] Looking for previous report: $yesterdayRemoteJson"

    # Check if previous report exists on SFTP
    Write-Host "[INFO] Checking for previous day's status report..."
    $yesterdayReportFileExists = Test-SFTPPath -SessionId $SFTPSession.SessionId -Path $yesterdayRemoteJson -ErrorAction SilentlyContinue

    # Get termination threshold and today's termination count
    $terminationThreshold = $SourceConfig.LcsCalculationRules.TerminationThreshold
    $todayTerminations = if ($statusCounts.ContainsKey('terminated')) { $statusCounts['terminated'] } else { 0 }
    
    Write-Host "[INFO] Today's termination count: $todayTerminations"
    Write-Host "[INFO] Termination spike threshold: $terminationThreshold"

    if ($yesterdayReportFileExists) {
        Write-Host "[INFO] Previous report found - proceeding with spike detection analysis"
        
        try {
            # Setup temporary folder path
            $tempFolder = if ($env:Agent_TempDirectory) {
                Join-Path -Path $env:Agent_TempDirectory -ChildPath "SFTPTemp"
            } else {
                Join-Path -Path $env:TEMP -ChildPath "SFTPTemp"
            }
            Write-Host "[DEBUG] Temporary folder for download: $tempFolder"

            # Ensure temporary folder exists
            if (-not (Test-Path $tempFolder)) {
                Write-Host "[INFO] Creating temporary folder..."
                New-Item -Path $tempFolder -ItemType Directory | Out-Null
                Write-Host "[SUCCESS] Temporary folder created"
            }

            # Define local path for downloaded file
            $tempFile = "$tempFolder\status_count_$($SourceConfig.SourceName)_$targetDate.json"
            Write-Host "[DEBUG] Local temp file path: $tempFile"
            
            # Remove existing temp file if present
            if (Test-Path $tempFile) {
                Write-Host "[WARNING] Local temp file already exists - removing: $tempFile"
                Remove-Item -Path $tempFile -Force
                Write-Host "[SUCCESS] Existing temp file removed"
            }
            
            # Download previous report from SFTP
            Write-Host "[INFO] Downloading previous report from SFTP..."
            Get-SFTPItem -SessionId $SFTPSession.SessionId `
                -Path $yesterdayRemoteJson `
                -Destination $tempFolder `
                -ErrorAction Stop
            Write-Host "[SUCCESS] Previous report downloaded"

            # Read and parse previous report JSON
            Write-Host "[INFO] Parsing previous report JSON..."
            $yesterdayReport = Get-Content $tempFile | ConvertFrom-Json
            $yesterdayTerminations = if ($yesterdayReport.StatusCounts.terminated) { 
                [int]$yesterdayReport.StatusCounts.terminated 
            } else { 
                0 
            }
            
            # Calculate termination increase
            $terminationIncrease = $todayTerminations - $yesterdayTerminations

            Write-Host "`n[ANALYSIS] Termination Spike Analysis:"
            Write-Host "[ANALYSIS]   - Previous date: $targetDate"
            Write-Host "[ANALYSIS]   - Previous terminations: $yesterdayTerminations"
            Write-Host "[ANALYSIS]   - Today's terminations: $todayTerminations"
            Write-Host "[ANALYSIS]   - Increase: $terminationIncrease"
            Write-Host "[ANALYSIS]   - Threshold: $terminationThreshold"
            Write-Host "[ANALYSIS]   - Status: $(if ($terminationIncrease -gt $terminationThreshold) { 'SPIKE DETECTED' } else { 'NORMAL' })"

            # Check if termination increase exceeds threshold
            if ($terminationIncrease -gt $terminationThreshold) {
                Write-Host "`n[ALERT] =========================================="
                Write-Host "[ALERT] TERMINATION SPIKE DETECTED!"
                Write-Host "[ALERT] =========================================="
                Write-Host "[ALERT] Termination increase ($terminationIncrease) exceeds threshold ($terminationThreshold)"
                Write-Host "[ALERT] Processing STOPPED for manual review"

                # Generate alert email body
                $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                $alertBody = @"
ALERT: Unusual termination spike detected for $($SourceConfig.SourceName)

Previous date: $targetDate
Previous terminations: $yesterdayTerminations
Today's terminations: $todayTerminations
Increase: $terminationIncrease
Threshold: $terminationThreshold

Processing has been stopped for manual review.
Please verify the data before reprocessing.

Generated: $timestamp
"@

                Write-Host "[INFO] Sending termination spike alert email..."
                Send-ValidationEmail -EmailConfig $EmailConfig `
                    -Subject "$($EmailConfig.Subject) TERMINATION SPIKE ALERT" `
                    -Body $alertBody
                Write-Host "[INFO] Alert email sent"

                Write-Host "[ERROR] Validation stopped due to termination spike - mandatory field validation skipped"
                Remove-SFTPSession -SessionId $SFTPSession.SessionId
                return 1
            } else {
                Write-Host "[SUCCESS] Termination increase within acceptable range - proceeding with validation"
            }
        } catch {
            Write-Host "[WARNING] Could not read/parse previous report: $_"
            Write-Host "[WARNING] Stack trace: $($_.ScriptStackTrace)"
            Write-Host "[INFO] Proceeding with validation (unable to perform spike detection)"
            return 1
        }
    } else {
        Write-Host "[WARNING] No previous report found on SFTP"
        Write-Host "[INFO] This may be the first run - proceeding with validation (spike detection skipped)"
    }

    # ================================================================================
    # STEP 6: MANDATORY FIELD VALIDATION (NON-TERMINATED ONLY)
    # ================================================================================
    Write-Host "`n================================================================================"
    Write-Host "[STEP 6] MANDATORY FIELD VALIDATION"
    Write-Host "================================================================================"

    Write-Host "[INFO] Validating mandatory fields for non-terminated employees..."
    Write-Host "[DEBUG] Mandatory fields to check: $($SourceConfig.MandatoryFields.Count)"
    Write-Host "[DEBUG] Fields: $($SourceConfig.MandatoryFields -join ', ')"
    
    # Initialize tracking arrays
    $validationMessages = @()
    $nonTerminatedCount = 0
    $validationProgress = 0

    foreach ($employee in $employees) {
        $validationProgress++
        
        # Log progress every 100 employees
        if ($validationProgress % 100 -eq 0) {
            Write-Host "[PROGRESS] Validated mandatory fields for $validationProgress / $($employees.Count) employees..."
        }
        
        # Recalculate status for this employee
        $status = Get-EmployeeStatusBySource -SourceName $SourceConfig.SourceName -Employee $employee -LcsRules $lcsRules

        # Only validate non-terminated employees
        if ($status -ne 'terminated') {
            $nonTerminatedCount++
            $missingFields = @()

            # Check each mandatory field
            foreach ($field in $SourceConfig.MandatoryFields) {
                $value = $employee.$field
                
                # Consider field missing if null or whitespace
                if ($null -eq $value) {
                    $missingFields += $field
                } elseif ($value -is [string] -and [string]::IsNullOrWhiteSpace($value)) {
                    $missingFields += $field
                }
            }

            # If any mandatory fields are missing, add to validation messages
            if ($missingFields.Count -gt 0) {
                $employeeName = Get-EmployeeName -Employee $employee -SourceConfig $SourceConfig
                
                $validationMessages += [PSCustomObject]@{
                    EmployeeName = $employeeName
                    EmployeeNumber = $employee.EMPLOYEENUMBER
                    EmployeeStatus = $status
                    MissingFields = ($missingFields -join ', ')
                }
                
                Write-Host "[WARNING] Employee $employeeName ($($employee.EMPLOYEENUMBER)) - Status: $status - Missing fields: $($missingFields -join ', ')"
            }
        }
    }

    Write-Host "`n[SUCCESS] Mandatory field validation completed"
    Write-Host "[SUMMARY] Non-terminated employees checked: $nonTerminatedCount"
    Write-Host "[SUMMARY] Employees with missing fields: $($validationMessages.Count)"
    
    if ($validationMessages.Count -eq 0) {
        Write-Host "[SUCCESS] All non-terminated employees have complete mandatory fields"
    }

    # ================================================================================
    # STEP 7: EMAIL REPORTING AND SFTP UPLOAD
    # ================================================================================
    Write-Host "`n================================================================================"
    Write-Host "[STEP 7] VALIDATION REPORT GENERATION AND DISTRIBUTION"
    Write-Host "================================================================================"

    if ($validationMessages.Count -gt 0) {
        Write-Host "[INFO] Validation issues found - generating report..."
        
        # Generate local CSV report
        $localCsv = Join-Path $TempDir "HR_Validation_Report_$($SourceConfig.SourceName)_$todayStr.csv"
        Write-Host "[DEBUG] Report path: $localCsv"
        
        Write-Host "[INFO] Exporting validation issues to CSV..."
        $validationMessages | Export-Csv -Path $localCsv -NoTypeInformation -Encoding UTF8
        Write-Host "[SUCCESS] CSV report generated with $($validationMessages.Count) records"

        # Upload report to SFTP
        Write-Host "[INFO] Uploading validation report to SFTP..."
        Upload-Replace -LocalFilePath $localCsv -RemoteDir $ReportRemoteDir -RemoteFileName (Split-Path $localCsv -Leaf)
        Write-Host "[SUCCESS] Report uploaded to SFTP: $ReportRemoteDir"

        # Prepare email body
        $bodyMessage = "Found $($validationMessages.Count) non-terminated employees with missing mandatory fields for $($SourceConfig.SourceName).`n`nGenerated: $timestamp`n`nPlease review the attached report and provide the missing information."
        
        # Send email notification with attachment
        Write-Host "[INFO] Sending validation report email..."
        Send-ValidationEmail -EmailConfig $EmailConfig `
            -Subject "$($EmailConfig.Subject) - Missing Mandatory Fields" `
            -Body $bodyMessage `
            -AttachmentPath $localCsv
        Write-Host "[SUCCESS] Email sent with validation report attached"
        
        Write-Host "[SUMMARY] Validation report distributed - $($validationMessages.Count) employees with issues"
    } else {
        Write-Host "[SUCCESS] No validation issues found - no report needed"
    }

    # ================================================================================
    # STEP 8: CONDITIONAL FILE PROCESSING
    # ================================================================================
    Write-Host "`n================================================================================"
    Write-Host "[STEP 8] FILE PROCESSING AND MOVEMENT"
    Write-Host "================================================================================"

    Write-Host "[INFO] Preparing file for processing folder..."
    
    # Get source file information
    $SourceFileName = $SourceConfig.SourceFileName
    $sourceRemotePath = Join-Path $SourceFolder $SourceFileName
    $sourceRemotePath = Normalize-RemotePath $sourceRemotePath
    
    Write-Host "[DEBUG] Source filename: $SourceFileName"
    Write-Host "[DEBUG] Source remote path: $sourceRemotePath"
    
    # Check if validation failures exist
    $hasValidationFailures = ($validationMessages.Count -gt 0)
    Write-Host "[DEBUG] Validation failures present: $hasValidationFailures"
    Write-Host "[DEBUG] Validation failure count: $($validationMessages.Count)"

    # Define processing directory paths
    $processingRemoteDir = Normalize-RemotePath (Join-Path $SourceFolder "processing")
    $processingRemoteTarget = Normalize-RemotePath (Join-Path $processingRemoteDir $SourceFileName)
    $tempSourceLocalPath = Join-Path $TempDir $SourceFileName
    
    Write-Host "[DEBUG] Processing remote directory: $processingRemoteDir"
    Write-Host "[DEBUG] Processing remote target: $processingRemoteTarget"
    Write-Host "[DEBUG] Temp source local path: $tempSourceLocalPath"

    # Apply processing logic based on validation mode
    Write-Host "`n[INFO] Applying file processing logic..."
    Write-Host "[INFO] Process validation mode: $($SourceConfig.processValidation)"
    
    if ($SourceConfig.processValidation) {
        # STRICT MODE: Only process if validation passed
        Write-Host "[INFO] Operating in STRICT validation mode"
        
        if (-not $hasValidationFailures) {
            Write-Host "[SUCCESS] No validation failures - proceeding with file copy"
            
            replace-processingFile -sourceRemotePath $sourceRemotePath `
                -TempDir $TempDir `
                -tempSourceLocalPath $tempSourceLocalPath `
                -processingRemoteDir $processingRemoteDir `
                -SourceFileName $SourceFileName
            
            Write-Host "[SUCCESS] File successfully copied to processing folder (strict mode - validation passed)"
            Write-Host "[SUCCESS] Processing directory: $processingRemoteDir"
        } else {
            Write-Host "[WARNING] Validation failures detected - file NOT copied to processing folder"
            Write-Host "[WARNING] Missing mandatory fields: $($validationMessages.Count) employees"
            Write-Host "[ERROR] File processing blocked due to validation issues"
            return 1
        }
    } else {
        # NON-STRICT MODE: Always process regardless of validation results
        Write-Host "[INFO] Operating in NON-STRICT validation mode"
        
        replace-processingFile -sourceRemotePath $sourceRemotePath `
            -TempDir $TempDir `
            -tempSourceLocalPath $tempSourceLocalPath `
            -processingRemoteDir $processingRemoteDir `
            -SourceFileName $SourceFileName
        
        Write-Host "[SUCCESS] File copied to processing folder (non-strict mode)"
        Write-Host "[SUCCESS] Processing directory: $processingRemoteDir"
        
        if ($hasValidationFailures) {
            Write-Host "[WARNING] File copied despite $($validationMessages.Count) validation issues"
            Write-Host "[WARNING] Manual review recommended before final processing"
        }
    }

    # ================================================================================
    # VALIDATION COMPLETION SUMMARY
    # ================================================================================
    Write-Host "`n================================================================================"
    Write-Host "[SUCCESS] VALIDATION PROCESS COMPLETED"
    Write-Host "================================================================================"
    Write-Host "[SUMMARY] Source: $($SourceConfig.SourceName)"
    Write-Host "[SUMMARY] Total employees processed: $($employees.Count)"
    Write-Host "[SUMMARY] Status distribution:"
    foreach ($status in $statusCounts.Keys | Sort-Object) {
        Write-Host "[SUMMARY]   - $status : $($statusCounts[$status])"
    }
    Write-Host "[SUMMARY] Non-terminated employees: $nonTerminatedCount"
    Write-Host "[SUMMARY] Employees with missing fields: $($validationMessages.Count)"
    Write-Host "[SUMMARY] File processing mode: $(if ($SourceConfig.processValidation) { 'STRICT' } else { 'NON-STRICT' })"
    Write-Host "[SUMMARY] Processing result: $(if ($hasValidationFailures -and $SourceConfig.processValidation) { 'BLOCKED' } else { 'SUCCESS' })"
    Write-Host "[SUMMARY] Completed at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Write-Host "================================================================================"

    # Cleanup SFTP session
    Write-Host "`n[INFO] Cleaning up SFTP session..."
    Remove-SFTPSession -SessionId $SFTPSession.SessionId
    Write-Host "[SUCCESS] SFTP session closed"
    
    return 0
}

# ================================================================================
# HELPER FUNCTIONS
# ================================================================================

# --------------------------------------------------------------------------------
# FUNCTION: Get-EmployeeName
# --------------------------------------------------------------------------------
function Get-EmployeeName {
    param (
        $Employee,
        $SourceConfig
    )

    Write-Host "[DEBUG] Extracting employee name..."
    $nameFields = $SourceConfig.EmployeeNameFields
    $firstName = $Employee.($nameFields.FirstName)
    $lastName = $Employee.($nameFields.LastName)
    $fullName = "$firstName $lastName"
    Write-Host "[DEBUG] Employee name: $fullName"
    
    return $fullName
}

# --------------------------------------------------------------------------------
# FUNCTION: Send-ValidationEmail
# --------------------------------------------------------------------------------
function Send-ValidationEmail {
    param (
        [hashtable]$EmailConfig,
        [string]$Subject,
        [string]$Body,
        [string]$AttachmentPath = $null
    )

    Write-Host "[INFO] Preparing to send email notification..."
    Write-Host "[DEBUG] Subject: $Subject"
    Write-Host "[DEBUG] From: $($EmailConfig.FromAddress)"
    Write-Host "[DEBUG] To: $($EmailConfig.ToAddress -join ', ')"
    
    # Build email parameters
    $emailParams = @{
        From = $EmailConfig.FromAddress
        To = $EmailConfig.ToAddress
        Subject = $Subject
        Body = $Body
        SmtpServer = $EmailConfig.SmtpServer
    }
    
    # Add CC recipients if configured
    if ($EmailConfig.CcAddress -and $EmailConfig.CcAddress.Count -gt 0) {
        $emailParams.Add("Cc", $EmailConfig.CcAddress)
        Write-Host "[DEBUG] CC: $($EmailConfig.CcAddress -join ', ')"
    }
    
    # Add attachment if provided
    if ($AttachmentPath -and (Test-Path $AttachmentPath)) {
        $emailParams.Add("Attachments", $AttachmentPath)
        Write-Host "[DEBUG] Attachment: $AttachmentPath"
    }
    
    # Send email
    try {
        Send-MailMessage @emailParams -ErrorAction Stop
        Write-Host "[SUCCESS] Email sent successfully"
    } catch {
        Write-Host "[ERROR] Failed to send email: $_"
        Write-Host "[ERROR] Stack trace: $($_.ScriptStackTrace)"
        Write-Error "Failed to send email: $_"
    }
}

# ================================================================================
# MODULE EXPORTS
# ================================================================================
Export-ModuleMember -Function Start-Validation
