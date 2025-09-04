# Unified Validation Module - Final Version
# Includes all features: multi-source support, termination spike detection, conditional file processing

function Start-UnifiedValidation {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [hashtable]$SourceConfig,
        
        [Parameter(Mandatory=$true)]
        [string]$CsvFilePath,
        
        [Parameter(Mandatory=$true)]
        [hashtable]$EmailConfig,
        
        [Parameter(Mandatory=$true)]
        [string]$HCMbackupFolder,
        
        [Parameter(Mandatory=$true)]
        [Boolean]$ValidationProcessFlag
    )

    Write-Host "=========================================="
    Write-Host "Starting unified validation for source: $($SourceConfig.SourceName)"
    Write-Host "Processing file: $CsvFilePath"
    Write-Host "Process validation mode: $($SourceConfig.processValidation)"
    Write-Host "=========================================="

    # Import required modules
    Import-Module -Name "Final_StatusCalculators.psm1" -Force

    # Validate that the CSV file exists
    if (-not (Test-Path -Path $CsvFilePath)) {
        Write-Error "CSV file not found: $CsvFilePath"
        return 1
    }

    try {
        $employees = Import-Csv -Path $CsvFilePath -ErrorAction Stop
        Write-Host "✅ Successfully imported $($employees.Count) employee records"
    }
    catch {
        Write-Error "❌ Failed to import CSV file: $_"
        return 1
    }

    # ===========================================
    # STEP 1: HEADER VALIDATION (FAIL-FAST)
    # ===========================================
    Write-Host "🔍 Step 1: Header validation..."
    
    $headerLine = Get-Content -Path $CsvFilePath -TotalCount 1
    $headerColumns = $headerLine -split ','
    
    # Check header count
    if ($headerColumns.Count -ne $SourceConfig.HeaderCount) {
        $bodyMessage = "❌ Header Count mismatch for $($SourceConfig.SourceName).`nExpected: $($SourceConfig.HeaderCount)`nFound: $($headerColumns.Count)`n`nPlease verify the file format and try again."
        Send-ValidationEmail -EmailConfig $EmailConfig -Subject "$($EmailConfig.Subject) - Header Count Mismatch" -Body $bodyMessage
        Write-Host "❌ Header count validation FAILED. Expected: $($SourceConfig.HeaderCount), Found: $($headerColumns.Count)"
        return 1
    }
    
    # Check header fields
    foreach ($requiredHeader in $SourceConfig.HeaderFields) {
        if ($headerColumns -notcontains $requiredHeader) {
            $bodyMessage = "❌ Missing required header field '$requiredHeader' for $($SourceConfig.SourceName).`n`nRequired headers: $($SourceConfig.HeaderFields -join ', ')`n`nPlease verify the file format and try again."
            Send-ValidationEmail -EmailConfig $EmailConfig -Subject "$($EmailConfig.Subject) - Missing Header Field" -Body $bodyMessage
            Write-Host "❌ Header field validation FAILED. Missing: $requiredHeader"
            return 1
        }
    }
    
    Write-Host "✅ Header validation passed successfully"

    # ===========================================
    # STEP 2: DATE VALIDATION (FAIL-FAST)
    # ===========================================
    Write-Host "🔍 Step 2: Date validation for all employees..."

    $inputFormat = $SourceConfig.DateFormat
    $invalidHireDateList = @()
    $missingHireDateList = @()
    $invalidTerminationDateList = @()

    foreach ($employee in $employees) {
        $employeeNumber = $employee.EMPLOYEENUMBER

        # Check hire dates
        if (![string]::IsNullOrWhiteSpace($employee.HIRE_DATE)) {
            try {
                [DateTime]::ParseExact($employee.HIRE_DATE, $inputFormat, $null) | Out-Null
            } catch {
                $invalidHireDateList += $employee
                Write-Host "⚠️ Invalid hire date for employee $employeeNumber: $($employee.HIRE_DATE)"
            }
        } else {
            $missingHireDateList += $employee
            Write-Host "⚠️ Missing hire date for employee $employeeNumber"
        }
        
        # Check termination dates (if present)
        if (![string]::IsNullOrWhiteSpace($employee.TERMINATION_DATE)) {
            try {
                [DateTime]::ParseExact($employee.TERMINATION_DATE, $inputFormat, $null) | Out-Null
            } catch {
                $invalidTerminationDateList += $employee
                Write-Host "⚠️ Invalid termination date for employee $employeeNumber: $($employee.TERMINATION_DATE)"
            }
        }
    }

    # Create processing directory
    $processingDir = Join-Path $HCMbackupFolder "processing"
    if (-not (Test-Path $processingDir)) {
        New-Item -Path $processingDir -ItemType Directory -Force
    }

    # If date validation fails, send email and STOP
    if ($invalidHireDateList.Count -gt 0) {
        $invalidHireDatePath = Join-Path $processingDir "invalid_hire_dates_$($SourceConfig.SourceName).csv"
        $invalidHireDateList | Export-Csv -Path $invalidHireDatePath -NoTypeInformation
        
        $bodyMessage = "❌ Found $($invalidHireDateList.Count) employees with invalid hire dates for $($SourceConfig.SourceName).`nExpected format: $($SourceConfig.DateFormat)`n`nPlease fix the dates and resubmit the file."
        Send-ValidationEmail -EmailConfig $EmailConfig -Subject "$($EmailConfig.Subject) - Invalid Hire Dates" -Body $bodyMessage -AttachmentPath $invalidHireDatePath
        Write-Host "❌ Date validation FAILED - Invalid hire dates found"
        return 1
    }

    if ($missingHireDateList.Count -gt 0) {
        $missingHireDatePath = Join-Path $processingDir "missing_hire_dates_$($SourceConfig.SourceName).csv"
        $missingHireDateList | Export-Csv -Path $missingHireDatePath -NoTypeInformation
        
        $bodyMessage = "❌ Found $($missingHireDateList.Count) employees with missing hire dates for $($SourceConfig.SourceName).`n`nPlease provide hire dates for all employees and resubmit the file."
        Send-ValidationEmail -EmailConfig $EmailConfig -Subject "$($EmailConfig.Subject) - Missing Hire Dates" -Body $bodyMessage -AttachmentPath $missingHireDatePath
        Write-Host "❌ Date validation FAILED - Missing hire dates found"
        return 1
    }

    if ($invalidTerminationDateList.Count -gt 0) {
        $invalidTermDatePath = Join-Path $processingDir "invalid_termination_dates_$($SourceConfig.SourceName).csv"
        $invalidTerminationDateList | Export-Csv -Path $invalidTermDatePath -NoTypeInformation
        
        $bodyMessage = "❌ Found $($invalidTerminationDateList.Count) employees with invalid termination dates for $($SourceConfig.SourceName).`nExpected format: $($SourceConfig.DateFormat)`n`nPlease fix the dates and resubmit the file."
        Send-ValidationEmail -EmailConfig $EmailConfig -Subject "$($EmailConfig.Subject) - Invalid Termination Dates" -Body $bodyMessage -AttachmentPath $invalidTermDatePath
        Write-Host "❌ Date validation FAILED - Invalid termination dates found"
        return 1
    }

    Write-Host "✅ Date validation passed successfully"

    # ===========================================
    # STEP 3: EMPLOYEE STATUS CALCULATION
    # ===========================================
    Write-Host "🔍 Step 3: Calculating employee status for all employees..."

    $outputFormat = "yyyy-MM-dd'T'HH:mm:ss.fff'Z'"
    $lcsRules = $SourceConfig.LcsCalculationRules
    $statusCounts = @{}

    $nowRaw = [DateTime]::UtcNow
    $nowRounded = $nowRaw.AddMilliseconds(500 - ($nowRaw.Millisecond % 1000))
    $now = $nowRounded.ToString($outputFormat)
    $nowRoundedToDay = [DateTime]::UtcNow.Date

    Write-Host "Current UTC Time (Rounded): $now"

    foreach ($employee in $employees) {
        $employeeNumber = $employee.EMPLOYEENUMBER
        $employeeStartDate = if (![string]::IsNullOrWhiteSpace($employee.HIRE_DATE)) { $employee.HIRE_DATE } else { "NoValue" }
        $employeeStatus = $employee.EMPLOYEE_STATUS

        # Parse hire date (guaranteed to be valid from Step 2)
        $convertedHireDateDT = $null
        if (![string]::IsNullOrWhiteSpace($employee.HIRE_DATE)) {
            $convertedHireDateDT = [DateTime]::ParseExact($employee.HIRE_DATE, $inputFormat, $null)
        }

        # Calculate status using source-specific logic
        $status = Get-EmployeeStatusBySource -SourceName $SourceConfig.SourceName -Employee $employee -ConvertedHireDateDT $convertedHireDateDT -NowRoundedToDay $nowRoundedToDay -LcsRules $lcsRules -EmployeeStartDate $employeeStartDate -EmployeeStatus $employeeStatus

        # Count status
        if ($statusCounts.ContainsKey($status)) {
            $statusCounts[$status] += 1
        } else {
            $statusCounts[$status] = 1
        }
    }

    Write-Host "✅ Status calculation completed. Status counts: $($statusCounts | ConvertTo-Json -Compress)"

    # ===========================================
    # STEP 4: SAVE STATUS REPORT
    # ===========================================
    Write-Host "🔍 Step 4: Saving daily status report..."

    # Create report folder if it doesn't exist
    $reportDir = Join-Path $HCMbackupFolder "report"
    if (-not (Test-Path $reportDir)) {
        New-Item -Path $reportDir -ItemType Directory -Force
        Write-Host "Created report directory: $reportDir"
    }

    # Save today's status counts
    $today = Get-Date -Format "yyyy-MM-dd"
    $todayReportPath = Join-Path $reportDir "status_count_$($SourceConfig.SourceName)_$today.json"

    $statusReport = @{
        Date = $today
        SourceName = $SourceConfig.SourceName
        TotalEmployees = $employees.Count
        StatusCounts = $statusCounts
        ProcessedAt = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    }

    $statusReport | ConvertTo-Json -Depth 3 | Out-File -FilePath $todayReportPath -Encoding UTF8
    Write-Host "✅ Status report saved: $todayReportPath"

    # ===========================================
    # STEP 5: TERMINATION SPIKE DETECTION
    # ===========================================
    Write-Host "🔍 Step 5: Checking for termination spikes..."

    $yesterday = (Get-Date).AddDays(-1).ToString("yyyy-MM-dd")
    $yesterdayReportPath = Join-Path $reportDir "status_count_$($SourceConfig.SourceName)_$yesterday.json"

    $terminationThreshold = $SourceConfig.LcsCalculationRules.TerminationThreshold
    $todayTerminations = if ($statusCounts.ContainsKey('terminated')) { $statusCounts['terminated'] } else { 0 }

    if (Test-Path $yesterdayReportPath) {
        try {
            $yesterdayReport = Get-Content $yesterdayReportPath | ConvertFrom-Json
            $yesterdayTerminations = if ($yesterdayReport.StatusCounts.terminated) { $yesterdayReport.StatusCounts.terminated } else { 0 }
            
            $terminationIncrease = $todayTerminations - $yesterdayTerminations
            
            Write-Host "Termination Analysis:"
            Write-Host "- Yesterday terminations: $yesterdayTerminations"
            Write-Host "- Today terminations: $todayTerminations"
            Write-Host "- Increase: $terminationIncrease"
            Write-Host "- Threshold: $terminationThreshold"
            
            if ($terminationIncrease -gt $terminationThreshold) {
                Write-Host "❌ TERMINATION SPIKE DETECTED!"
                Write-Host "   Termination increase ($terminationIncrease) exceeds threshold ($terminationThreshold)"
                
                # Send alert email
                $alertBody = @"
🚨 ALERT: Unusual termination spike detected for $($SourceConfig.SourceName)

Yesterday terminations: $yesterdayTerminations
Today terminations: $todayTerminations
Increase: $terminationIncrease
Threshold: $terminationThreshold

Processing has been stopped for manual review.
Please verify the data before reprocessing.

Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
"@
                
                Send-ValidationEmail -EmailConfig $EmailConfig -Subject "$($EmailConfig.Subject) - 🚨 TERMINATION SPIKE ALERT" -Body $alertBody
                
                Write-Host "❌ Stopping process - mandatory field validation skipped due to termination spike"
                return 1
            } else {
                Write-Host "✅ Termination increase within acceptable range"
            }
        } catch {
            Write-Host "⚠️ Could not read yesterday's report: $_"
            Write-Host "Proceeding with validation (first run or file issue)"
        }
    } else {
        Write-Host "⚠️ No yesterday report found - proceeding with validation (first run)"
    }

    # ===========================================
    # STEP 6: MANDATORY FIELD VALIDATION (NON-TERMINATED ONLY)
    # ===========================================
    Write-Host "🔍 Step 6: Mandatory field validation for non-terminated employees..."

    $validationMessages = @()
    $nonTerminatedCount = 0

    foreach ($employee in $employees) {
        $employeeNumber = $employee.EMPLOYEENUMBER
        $employeeStartDate = if (![string]::IsNullOrWhiteSpace($employee.HIRE_DATE)) { $employee.HIRE_DATE } else { "NoValue" }
        $employeeStatus = $employee.EMPLOYEE_STATUS

        # Parse hire date (guaranteed to be valid from Step 2)
        $convertedHireDateDT = $null
        if (![string]::IsNullOrWhiteSpace($employee.HIRE_DATE)) {
            $convertedHireDateDT = [DateTime]::ParseExact($employee.HIRE_DATE, $inputFormat, $null)
        }

        # Calculate status using source-specific logic
        $status = Get-EmployeeStatusBySource -SourceName $SourceConfig.SourceName -Employee $employee -ConvertedHireDateDT $convertedHireDateDT -NowRoundedToDay $nowRoundedToDay -LcsRules $lcsRules -EmployeeStartDate $employeeStartDate -EmployeeStatus $employeeStatus

        # Check mandatory fields ONLY for non-terminated employees
        if ($status -ne 'terminated') {
            $nonTerminatedCount++
            
            $missingFields = @()
            
            foreach ($field in $SourceConfig.MandatoryFields) {
                $value = $employee.$field
                
                if ($null -eq $value) {
                    $missingFields += $field
                } elseif ($value -is [string] -and [string]::IsNullOrWhiteSpace($value)) {
                    $missingFields += $field
                }
            }

            if ($missingFields.Count -gt 0) {
                # Get employee name based on source configuration
                $employeeName = Get-EmployeeName -Employee $employee -SourceConfig $SourceConfig

                $validationMessages += [PSCustomObject]@{
                    EmployeeName  = $employeeName
                    EmployeeNumber = $employeeNumber
                    EmployeeStatus = $status
                    MissingFields = ($missingFields -join ', ')
                }
                
                Write-Host "⚠️ Non-terminated employee $employeeName ($status) has missing fields: $($missingFields -join ', ')"
            }
        }
    }

    Write-Host "✅ Mandatory field validation completed for $nonTerminatedCount non-terminated employees"
    Write-Host "   Found $($validationMessages.Count) employees with missing mandatory fields"

    # ===========================================
    # STEP 7: EMAIL REPORTING
    # ===========================================
    Write-Host "🔍 Step 7: Sending validation reports..."

    # Send validation issues report (only for non-terminated employees with missing fields)
    if ($validationMessages.Count -gt 0) {
        $csvPath = Join-Path $processingDir "HR_Validation_Report_Non_Terminated_$($SourceConfig.SourceName).csv"
        $validationMessages | Export-Csv -Path $csvPath -NoTypeInformation
        
        $bodyMessage = "⚠️ Found $($validationMessages.Count) non-terminated employees with missing mandatory fields for $($SourceConfig.SourceName).`n`nGenerated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n`nPlease review the attached report and provide the missing information."
        
        Send-ValidationEmail -EmailConfig $EmailConfig -Subject "$($EmailConfig.Subject) - Missing Mandatory Fields" -Body $bodyMessage -AttachmentPath $csvPath
        
        Write-Host "✅ Validation issues report sent: $($validationMessages.Count) employees"
        Remove-Item $csvPath -ErrorAction SilentlyContinue
    } else {
        Write-Host "✅ No validation issues found for non-terminated employees"
    }

    # ===========================================
    # STEP 8: CONDITIONAL FILE PROCESSING
    # ===========================================
    Write-Host "🔍 Step 8: File processing based on validation results..."

    $hasValidationFailures = ($validationMessages.Count -gt 0)

    if ($SourceConfig.processValidation) {
        # Strict mode: Only copy file if no validation failures
        if (-not $hasValidationFailures) {
            $backupFileName = "$(Split-Path $CsvFilePath -Leaf)_$(Get-Date -Format 'yyyyMMddHHmmss')"
            $backupPath = Join-Path $HCMbackupFolder $backupFileName
            Copy-Item -Path $CsvFilePath -Destination $backupPath -Force
            Write-Host "✅ File copied to backup folder (strict mode - validation passed): $backupPath"
        } else {
            Write-Host "❌ File NOT copied to backup folder (strict mode - validation failures found)"
            Write-Host "   Missing mandatory fields: $($validationMessages.Count) employees"
            return 1
        }
    } else {
        # Lenient mode: Always copy file regardless of validation results
        $backupFileName = "$(Split-Path $CsvFilePath -Leaf)_$(Get-Date -Format 'yyyyMMddHHmmss')"
        $backupPath = Join-Path $HCMbackupFolder $backupFileName
        Copy-Item -Path $CsvFilePath -Destination $backupPath -Force
        Write-Host "✅ File copied to backup folder (lenient mode): $backupPath"
        if ($hasValidationFailures) {
            Write-Host "   Note: File copied despite $($validationMessages.Count) validation issues"
        }
    }

    Write-Host "=========================================="
    Write-Host "✅ Validation completed successfully for $($SourceConfig.SourceName)"
    Write-Host "Summary:"
    Write-Host "- Total employees processed: $($employees.Count)"
    Write-Host "- Status counts: $($statusCounts | ConvertTo-Json -Compress)"
    Write-Host "- Non-terminated employees: $nonTerminatedCount"
    Write-Host "- Missing field issues: $($validationMessages.Count)"
    Write-Host "- File processing mode: $($SourceConfig.processValidation)"
    Write-Host "=========================================="

    return 0
}

# ===========================================
# HELPER FUNCTIONS
# ===========================================

function Get-EmployeeName {
    param (
        $Employee,
        $SourceConfig
    )

    $nameFields = $SourceConfig.EmployeeNameFields
    $firstName = $Employee.($nameFields.FirstName)
    $lastName = $Employee.($nameFields.LastName)
    
    return "$firstName $lastName"
}

function Send-ValidationEmail {
    param (
        [hashtable]$EmailConfig,
        [string]$Subject,
        [string]$Body,
        [string]$AttachmentPath = $null
    )

    $emailParams = @{
        From       = $EmailConfig.FromAddress
        To         = $EmailConfig.ToAddress
        Subject    = $Subject
        Body       = $Body
        SmtpServer = $EmailConfig.SmtpServer
    }
    
    if ($EmailConfig.CcAddress -and $EmailConfig.CcAddress.Count -gt 0) {
        $emailParams.Add("Cc", $EmailConfig.CcAddress)
    }
    
    if ($AttachmentPath -and (Test-Path $AttachmentPath)) {
        $emailParams.Add("Attachments", $AttachmentPath)
    }
    
    try {
        Send-MailMessage @emailParams -ErrorAction Stop
        Write-Host "📧 Email sent successfully: $Subject"
    } catch {
        Write-Error "❌ Failed to send email: $_"
    }
}

Export-ModuleMember -Function Start-UnifiedValidation