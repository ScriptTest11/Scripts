
function Get-HCMEmployeeStatus {
    param (
        $employee,
        $LcsRules
    )

    # --------------------------------------------------------------------------------
    # SECTION 1: Initialize date formatting and current time references
    # --------------------------------------------------------------------------------
    
    # Define output format for datetime strings (ISO 8601 with milliseconds)
    $outputFormat = "yyyy-MM-dd'T'HH:mm:ss.fff'Z'"
    
    # Get current UTC time
    $nowRaw = [DateTime]::UtcNow
    Write-Host "[DEBUG] Raw UTC time: $nowRaw"
    
    # Round milliseconds to nearest second for consistency
    $nowRounded = $nowRaw.AddMilliseconds(500 - ($nowRaw.Millisecond % 1000))
    $now = $nowRounded.ToString($outputFormat)
    Write-Host "[DEBUG] Rounded current time: $now"
    
    # Get current date (no time component) for date comparisons
    $nowRoundedToDay = [DateTime]::UtcNow.Date
    Write-Host "[DEBUG] Current date (day only): $nowRoundedToDay"
    
    # Extract employee identifiers for logging
    $employeeNumber = $employee.EMPLOYEENUMBER
    $employeeName = $employee.FIRST_NAME
    Write-Host "[INFO] Processing employee: $employeeName (Employee Number: $employeeNumber)"

    # --------------------------------------------------------------------------------
    # SECTION 2: Parse and validate HIRE_DATE field
    # --------------------------------------------------------------------------------
    Write-Host "[INFO] Step 1: Validating and parsing hire date..."
    
    $hireDateInput = $null
    
    # Check if hire date field is not empty
    if (![string]::IsNullOrWhiteSpace($employee.HIRE_DATE)) {
        Write-Host "[DEBUG] Hire date found: $($employee.HIRE_DATE)"
        
        try {
            # Parse hire date using expected format (MM-dd-yyyy)
            $hireDateInput = [DateTime]::ParseExact($employee.HIRE_DATE, "MM-dd-yyyy", $null)
            Write-Host "[INFO] Successfully parsed hire date: $hireDateInput"
        } catch {
            # Log parsing error but continue processing
            Write-Host "[ERROR] Invalid HIRE_DATE format for Employee Number: $employeeNumber, Value: $($employee.HIRE_DATE)"
            $invalidHireDateList += $employee
        }
    } else {
        Write-Host "[WARNING] Hire date is empty for Employee Number: $employeeNumber"
    }

    # --------------------------------------------------------------------------------
    # SECTION 3: Parse and validate TERMINATION_DATE field
    # --------------------------------------------------------------------------------
    Write-Host "[INFO] Step 2: Validating and parsing termination date..."
    
    $termDateInput = $null
    
    # Check if termination date field is not empty
    if (![string]::IsNullOrWhiteSpace($employee.TERMINATION_DATE)) {
        Write-Host "[DEBUG] Termination date found: $($employee.TERMINATION_DATE)"
        
        try {
            # Parse termination date using expected format (MM-dd-yyyy)
            $termDateInput = [DateTime]::ParseExact($employee.TERMINATION_DATE, "MM-dd-yyyy", $null)
            Write-Host "[INFO] Successfully parsed termination date: $termDateInput"
        } catch {
            # Log parsing error but continue processing
            Write-Host "[ERROR] Invalid TERMINATION_DATE format for Employee Number: $employeeNumber, Value: $($employee.TERMINATION_DATE)"
        }
    } else {
        Write-Host "[DEBUG] No termination date found for Employee Number: $employeeNumber"
    }

    # --------------------------------------------------------------------------------
    # SECTION 4: Set up status calculation variables
    # --------------------------------------------------------------------------------
    Write-Host "[INFO] Step 3: Preparing status calculation variables..."
    
    # Create flag indicating if termination date exists
    $termDate = if ($termDateInput) { "yes" } else { "no" }
    Write-Host "[DEBUG] Termination date exists: $termDate"
    
    # Extract employee status from source system
    $employeeStatus = $employee.EMPLOYEE_STATUS
    Write-Host "[DEBUG] Employee status from source: $employeeStatus"
    
    # Set employee start date (use "NoValue" if hire date is missing)
    $employeeStartDate = if (![string]::IsNullOrWhiteSpace($employee.HIRE_DATE)) { 
        $employee.HIRE_DATE 
    } else { 
        "NoValue" 
    }
    Write-Host "[DEBUG] Employee start date: $employeeStartDate"

    # --------------------------------------------------------------------------------
    # SECTION 5: Calculate key date thresholds for status determination
    # --------------------------------------------------------------------------------
    Write-Host "[INFO] Step 4: Calculating date-based thresholds..."
    
    # Convert hire date to DateTime for calculations
    $convertedHireDateDT = $hireDateInput
    
    # Calculate prehire window (14 days before hire date)
    $convertedHireDatepreHire = if ($convertedHireDateDT) { 
        $convertedHireDateDT.AddDays(-14).Date 
    } else { 
        $null 
    }
    if ($convertedHireDatepreHire) {
        Write-Host "[DEBUG] Prehire threshold date (14 days before hire): $convertedHireDatepreHire"
    }
    
    # Calculate hire date + 2 days (for new hire vs existing employee logic)
    $convertedEmpHireDate = if ($convertedHireDateDT) { 
        $convertedHireDateDT.AddDays(+2) 
    } else { 
        $null 
    }
    if ($convertedEmpHireDate) {
        Write-Host "[DEBUG] Hire date + 2 days threshold: $convertedEmpHireDate"
    }
    
    # Calculate hire date - 1 day (for new hire status determination)
    $convertedEmpHireDateOneDay = if ($convertedHireDateDT) { 
        $convertedHireDateDT.AddDays(-1) 
    } else { 
        $null 
    }
    if ($convertedEmpHireDateOneDay) {
        Write-Host "[DEBUG] Hire date - 1 day threshold: $convertedEmpHireDateOneDay"
    }

    # Determine if employee is a new hire or future hire based on hire date
    $empHireDateNegativeConditionLogic = if ($convertedEmpHireDateOneDay -lt $nowRoundedToDay) { 
        "NEWHIRE" 
    } else { 
        "FUTUREHIRE" 
    }
    Write-Host "[DEBUG] Hire date condition result: $empHireDateNegativeConditionLogic"
    
    # Calculate termination threshold (current date - 15 days)
    $termDateCalcNow = $nowRoundedToDay.AddDays(-15)
    Write-Host "[DEBUG] Termination threshold date (15 days ago): $termDateCalcNow"

    # --------------------------------------------------------------------------------
    # SECTION 6: Evaluate date-based conditions for status logic
    # --------------------------------------------------------------------------------
    Write-Host "[INFO] Step 5: Evaluating date conditions..."
    
    # Check if current date is after hire date
    $beforeHireDate = if ($convertedHireDateDT -and $nowRoundedToDay -gt $convertedHireDateDT) { 
        "yes" 
    } else { 
        "no" 
    }
    Write-Host "[DEBUG] Current date is after hire date: $beforeHireDate"
    
    # Check if current date is after prehire window start (14 days before hire)
    $fourteenDaysBeforeStartDate = if ($convertedHireDatepreHire -and $nowRoundedToDay -gt $convertedHireDatepreHire) { 
        "yes" 
    } else { 
        "no" 
    }
    Write-Host "[DEBUG] Current date is within prehire window (14 days before hire): $fourteenDaysBeforeStartDate"
    
    # Determine if employee is existing (hire date + 2 days has passed) or new hire
    $empHireDate = if ($convertedEmpHireDate -and $convertedEmpHireDate -lt $nowRoundedToDay) { 
        "EXISTING" 
    } else { 
        $empHireDateNegativeConditionLogic 
    }
    Write-Host "[DEBUG] Employee hire status classification: $empHireDate"
    
    # Check if current date is more than 14 days before hire date
    $fourteenDaysOrMoreBeforeStartDate = if ($convertedHireDatepreHire -and $nowRoundedToDay -lt $convertedHireDatepreHire) { 
        "yes" 
    } else { 
        "no" 
    }
    Write-Host "[DEBUG] Current date is more than 14 days before hire: $fourteenDaysOrMoreBeforeStartDate"

    # --------------------------------------------------------------------------------
    # SECTION 7: Apply business logic to determine final employee status
    # --------------------------------------------------------------------------------
    Write-Host "[INFO] Step 6: Determining final employee status based on business rules..."
    
    # STATUS DETERMINATION LOGIC
    # Priority order matters - first matching condition wins
    
    # PREHIRE STATUS - Employee with no term date, no hire date, but active status
    if ($termDate -eq 'no' -and $employeeStartDate -eq 'NoValue' -and $employeeStatus.StartsWith('Active')) {
        $status = 'prehire'
        Write-Host "[INFO] Status determined: PREHIRE (No term date, no hire date, Active status)"
    } 
    # PREHIRE STATUS - More than 14 days before hire date
    elseif ($fourteenDaysOrMoreBeforeStartDate -eq 'yes' -and $beforeHireDate -eq 'no') {
        $status = 'prehire'
        Write-Host "[INFO] Status determined: PREHIRE (More than 14 days before hire date)"
    } 
    # HIRE STATUS - Within 14 days before hire date
    elseif ($fourteenDaysBeforeStartDate -eq 'yes' -and $beforeHireDate -eq 'no') {
        $status = 'hire'
        Write-Host "[INFO] Status determined: HIRE (Within 14 days of hire date)"
    } 
    # HIRE STATUS - New hire classification
    elseif ($empHireDate -eq 'NEWHIRE') {
        $status = 'hire'
        Write-Host "[INFO] Status determined: HIRE (New hire classification)"
    } 
    # ACTIVE STATUS - No termination date and active status
    elseif ($termDate -eq 'no' -and $employeeStatus.StartsWith('Active')) {
        $status = 'active'
        Write-Host "[INFO] Status determined: ACTIVE (No termination, Active status)"
    } 
    # ACTIVE STATUS - Leave of absence or suspended (still considered active)
    elseif ($employeeStatus -in @('Leave of Absence', 'Suspended - Payroll Eligible', 'Suspended - No Payroll')) {
        $status = 'active'
        Write-Host "[INFO] Status determined: ACTIVE (Leave/Suspended status: $employeeStatus)"
    } 
    # ACTIVE STATUS - No termination date but inactive status
    elseif ($termDate -eq 'no' -and $employeeStatus.StartsWith('Inactive')) {
        $status = 'active'
        Write-Host "[INFO] Status determined: ACTIVE (No termination, Inactive status)"
    } 
    # ACTIVE STATUS - No termination date and layoff status
    elseif ($termDate -eq 'no' -and $employeeStatus -eq 'Layoff') {
        $status = 'active'
        Write-Host "[INFO] Status determined: ACTIVE (No termination, Layoff status)"
    } 
    # TERMINATED STATUS - Has termination date, inactive status, no hire date
    elseif ($termDate -eq 'yes' -and $employeeStatus.StartsWith('Inactive') -and $employeeStartDate -eq 'NoValue') {
        $status = 'terminated'
        Write-Host "[INFO] Status determined: TERMINATED (Has termination, Inactive, No hire date)"
    } 
    # TERMINATED STATUS - Has termination date, layoff status, no hire date
    elseif ($termDate -eq 'yes' -and $employeeStatus -eq 'Layoff' -and $employeeStartDate -eq 'NoValue') {
        $status = 'terminated'
        Write-Host "[INFO] Status determined: TERMINATED (Has termination, Layoff, No hire date)"
    } 
    # TERMINATED STATUS - Has termination date and layoff status
    elseif ($termDate -eq 'yes' -and $employeeStatus -eq 'Layoff') {
        $status = 'terminated'
        Write-Host "[INFO] Status determined: TERMINATED (Has termination, Layoff status)"
    } 
    # TERMINATED STATUS - Has termination date and inactive status
    elseif ($termDate -eq 'yes' -and $employeeStatus.StartsWith('Inactive')) {
        $status = 'terminated'
        Write-Host "[INFO] Status determined: TERMINATED (Has termination, Inactive status)"
    } 
    # UNKNOWN STATUS - None of the above conditions matched
    else {
        Write-Host "[WARNING] UNKNOWN STATUS - No matching condition found"
        Write-Host "[WARNING] Employee Number: $employeeNumber"
        Write-Host "[WARNING] Employee Name: $employeeName"
        Write-Host "[WARNING] Employee Status: $employeeStatus"
        Write-Host "[WARNING] Termination Date: $termDate"
        Write-Host "[WARNING] Hire Date: $employeeStartDate"
        $status = 'unknown'
    }
    
    Write-Host "[SUCCESS] Final calculated status for $employeeNumber ($employeeName): $status"
    Write-Host "========================================`n"
    
    return $status
}

function Get-EmployeeStatusBySource {
    param (
        [string]$SourceName,
        $Employee,
        $LcsRules
    )
    
    Write-Host "[INFO] Routing status calculation to source: $SourceName"
    
    # Route to appropriate source-specific status calculation function
    switch ($SourceName) {
        "HCM" { 
            Write-Host "[DEBUG] Routing to HCM status calculator"
            return Get-HCMEmployeeStatus -Employee $Employee -LcsRules $LcsRules 
        }
        "Tress" { 
            Write-Host "[DEBUG] Routing to Tress status calculator"
            return Get-TressEmployeeStatus -Employee $Employee -LcsRules $LcsRules 
        }
        "Prodensa" { 
            Write-Host "[DEBUG] Routing to Prodensa status calculator"
            return Get-ProdensaEmployeeStatus -Employee $Employee -LcsRules $LcsRules
        }
        default { 
            Write-Host "[ERROR] Unknown source system: $SourceName"
            Write-Error "Unknown source: $SourceName"
            return "unknown"
        }
    }
}

# ================================================================================
# MODULE EXPORTS
# Export functions for use by other modules
# ================================================================================
Export-ModuleMember -Function Get-EmployeeStatusBySource
