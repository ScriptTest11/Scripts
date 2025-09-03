# Install and import required module
Install-Module -Name Posh-SSH -Force -Scope CurrentUser -AllowClobber
Import-Module Posh-SSH

# Define paths and filenames
$HCMFolder = ""
$HCMbackupFolder = ""
$HCMFileName = ""
$TempDir = ""

# Email configuration
$emailFrom = ""
$HCMemailTo = ""
$sailpointTeamCC = ""

$sailpointTeamCCArray = $TeamCC -split ',' | Where-Object { $_.Trim() -ne '' } | ForEach-Object { $_.Trim() }
$HCMemailToArray = $emailTo -split ',' | Where-Object { $_.Trim() -ne '' } | ForEach-Object { $_.Trim() }

$smtpServer = "EM.com"

Write-Host "Script started."

try {
    $fullPath = Join-Path -Path $HCMFolder -ChildPath $HCMFileName
    $today = Get-Date -Format "yyyy-MM-dd"

    if (Test-Path $fullPath) {
    Write-Host "File Found"
        $timestamp = Get-Date -Format "yyyyMMddHHmmss"
        $backupFileName = "$HCMFileName-$timestamp"
        $localFilePath = Join-Path $TempDir $HCMFileName
        $backupFilePath = Join-Path $TempDir $backupFileName

        # Copy file to backup path
        Copy-Item -Path $fullPath -Destination $backupFilePath -Force

        $validationProcessFlag = $true
        $terminationThresshold = 20

        $headerCount = 70
        $headerFields = @("EMPLOYEENUMBER", "LAST_NAME", "FIRST_NAME", "COUNTRY", "WORK_LOCATION_NAME", "WORK_LOCATION_CODE", "WORK_LOCATION_ADDRESS", "WORK_LOCATION_CITY", "WORK_LOCATION_STATE", "WORK_LOCATION_ZIP", "DIVISION", "DIVISION_CODE", "BUSINESS_UNIT", "BU_CODE", "JOB_TITLE", "JOB_CODE", "DEPARTMENT", "DEPT_CODE", "BSV_CCL_DEPT", "PRIMARY_MANAGER", "PRIMARY_MANAGER_EMPLOYEE_NUMBER", "JOB_FAMILY", "JOB_FAMILY_CODE", "JOB_SUB_FAMILY", "JOB_SUB_FAMILY_CODE", "CAREER_LEVEL", "CAREER_LEVEL_CODE", "SALARY___HOURLY", "SALARY_GRADE", "FT_OR_PT", "HIRE_DATE", "WORKER_TYPE", "LAST_HIRE_DATE", "ENTERPRISE_DATE", "ASSIGNMENT_ID", "EMPLOYEE_STATUS", "ACTION_CODE", "ACTION_REASON_CODE", "COUNTRY_CODE", "COUNTRY_DESCRIPTION", "WORK_EMAIL", "EFFECTIVE_START_DATE", "EFFECTIVE_END_DATE", "ASSIGNMENT_NAME", "ASSIGNMENT_NUMBER", "ASSIGNMENT_STATUS_TYPE", "LOCATION_CODE", "PENDING_LOCATION_CODE", "SYSTEM_PERSON_TYPE", "DISPLAY_NAME", "USER_NAME", "LEGISLATION_CODE", "LEGAL_EMPLOYER", "LOCATION_ID", "SUPERVISOR_MANAGER_TYPE", "SHIFT_CODE", "AD_SYNC_LIST", "AD_DONOTSYNC_LIST", "EMAIL_ADDRESS_ID", "USER_GUID", "WORK_TELEPHONE", "UNION_CODE", "TERMINATION_DATE", "MIDDLE_NAME", "WORK_MOBILE", "CAREER_STREAM", "CAREER_STREAM_CODE", "PREFERRED_NAME", "WORKPLACE_LOCATION", "PREFERRED_LAST_NAME")
        $mandatoryFields = @("EMPLOYEENUMBER", "LAST_NAME", "FIRST_NAME", "COUNTRY", "DIVISION", "BUSINESS_UNIT", "DEPARTMENT", "BSV_CCL_DEPT", "PRIMARY_MANAGER", "SALARY___HOURLY", "HIRE_DATE", "EMPLOYEE_STATUS", "EFFECTIVE_START_DATE")

        $hcmSubject = "SailPoint - HCM HR File Validation $today"

        # Import validation module
        Import-Module -Name "FileValidator.psm1" -Force
        Write-Host "Validation started."
        # Start validation
        Start-EmployeeValidation `
            -CsvFilePath $backupFilePath.Trim() `
            -SmtpServer $smtpServer `
            -FromAddress $emailFrom `
            -ToAddress $HCMemailToArray `
            -CcAddress $sailpointTeamCCArray `
            -Subject $hcmSubject `
            -MandatoryFields $mandatoryFields `
            -HeaderCount $headerCount `
            -HeaderFields $headerFields `
            -ValidationProcessFlag $validationProcessFlag `
            -HCMbackupFolder $HCMbackupFolder
            #-TerminationThresshold $terminationThresshold `
            
    } else {
        Write-Host "$HCMFileName not received today."

        $subject = "SailPoint - HCM HR File Missing Notification"
        $body = @"
<p>Hello Team,</p>
<p>This is a reminder that the file <strong>.csv</strong> was not received on <strong>$today</strong>.</p>
<p>Please upload the file to the shared location at your earliest convenience. If you experience any issues or need assistance, please contact the SailPoint team.</p>
<p>Thank you for your attention.</p>
<br>
<p>Thank You<br>Cybersecurity Team</p>
"@

        # Uncomment to send email
        # Send-MailMessage -From $emailFrom -To $emailToArray -Cc $TeamCCArray -Subject $subject -Body $body -BodyAsHtml -SmtpServer $smtpServer

        Write-Host "File not received email sent"
    }
}
catch {
    Write-Host "ERROR: $_"
}

Write-Host "Script Completed."
