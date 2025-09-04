# Source-Specific Status Calculation Functions
# Final Version - Function-based approach for compatibility

# ===========================================
# MCH STATUS CALCULATOR
# ===========================================
function Get-MCHEmployeeStatus {
    param (
        $Employee,
        $ConvertedHireDateDT,
        $NowRoundedToDay,
        $LcsRules,
        $EmployeeStartDate,
        $EmployeeStatus
    )

    $preHireDays = $LcsRules.PreHireDays
    
    # MCH-specific complex logic (original business rules)
    $convertedHireDatepreHire = if ($ConvertedHireDateDT) { $ConvertedHireDateDT.AddDays(-$preHireDays).Date } else { $null }
    $convertedEmpHireDate = if ($ConvertedHireDateDT) { $ConvertedHireDateDT.AddDays(+2) } else { $null }
    $convertedEmpHireDateOneDay = if ($ConvertedHireDateDT) { $ConvertedHireDateDT.AddDays(-1) } else { $null }

    $empHireDateNegativeConditionLogic = if ($convertedEmpHireDateOneDay -lt $NowRoundedToDay) { "NEWHIRE" } else { "FUTUREHIRE" }
    $beforeHireDate = if ($ConvertedHireDateDT -and $NowRoundedToDay -gt $ConvertedHireDateDT) { "yes" } else { "no" }
    $fourteenDaysBeforeStartDate = if ($convertedHireDatepreHire -and $NowRoundedToDay -gt $convertedHireDatepreHire) { "yes" } else { "no" }
    $empHireDate = if ($convertedEmpHireDate -and $convertedEmpHireDate -lt $NowRoundedToDay) { "EXISTING" } else { $empHireDateNegativeConditionLogic }
    $fourteenDaysOrMoreBeforeStartDate = if ($convertedHireDatepreHire -and $NowRoundedToDay -lt $convertedHireDatepreHire) { "yes" } else { "no" }

    # MCH business rules (original logic preserved)
    $status = "unknown"
    if ($EmployeeStartDate -eq 'NoValue' -and $EmployeeStatus.StartsWith('Active')) {
        $status = 'prehire'
    } elseif ($fourteenDaysOrMoreBeforeStartDate -eq 'yes' -and $beforeHireDate -eq 'no') {
        $status = 'prehire'
    } elseif ($fourteenDaysBeforeStartDate -eq 'yes' -and $beforeHireDate -eq 'no') {
        $status = 'hire'
    } elseif ($empHireDate -eq 'NEWHIRE') {
        $status = 'hire'
    } elseif ($EmployeeStatus.StartsWith('Active')) {
        $status = 'active'
    } elseif ($EmployeeStatus -in @('Leave of Absence', 'Suspended - Payroll Eligible', 'Suspended - No Payroll')) {
        $status = 'active'
    } elseif ($EmployeeStatus -in @('Inactive', 'Layoff')) {
        $status = 'active'
    } elseif ($EmployeeStatus -in @('Inactive', 'Layoff') -and $EmployeeStartDate -eq 'NoValue') {
        $status = 'terminated'
    }

    Write-Host "MCH Status Calculation for Employee $($Employee.EMPLOYEENUMBER): $status"
    return $status
}

# ===========================================
# TRESS STATUS CALCULATOR
# ===========================================
function Get-TressEmployeeStatus {
    param (
        $Employee,
        $ConvertedHireDateDT,
        $NowRoundedToDay,
        $LcsRules,
        $EmployeeStartDate,
        $EmployeeStatus
    )

    $preHireDays = $LcsRules.PreHireDays  # 10 days for Tress
    
    # Tress-specific logic (simpler than MCH)
    $status = "unknown"
    
    if ([string]::IsNullOrWhiteSpace($EmployeeStartDate) -or $EmployeeStartDate -eq 'NoValue') {
        # No hire date - determine based on status
        if ($EmployeeStatus -eq 'Active') {
            $status = 'prehire'
        } else {
            $status = 'terminated'
        }
    } else {
        # Has hire date - use date-based logic
        $daysUntilHire = ($ConvertedHireDateDT - $NowRoundedToDay).Days
        
        if ($daysUntilHire -gt $preHireDays) {
            $status = 'prehire'
        } elseif ($daysUntilHire -gt 0) {
            $status = 'hire'
        } elseif ($EmployeeStatus -in @('Active', 'Leave', 'Medical Leave', 'Personal Leave')) {
            $status = 'active'
        } else {
            $status = 'terminated'
        }
    }

    Write-Host "Tress Status Calculation for Employee $($Employee.EMPLOYEENUMBER): $status (Days until hire: $($daysUntilHire))"
    return $status
}

# ===========================================
# PRODENSA STATUS CALCULATOR
# ===========================================
function Get-ProdensaEmployeeStatus {
    param (
        $Employee,
        $ConvertedHireDateDT,
        $NowRoundedToDay,
        $LcsRules,
        $EmployeeStartDate,
        $EmployeeStatus
    )

    # Prodensa uses status-first approach (completely different from MCH/Tress)
    $status = "unknown"
    
    # Focus on system status first
    switch ($EmployeeStatus.ToUpper()) {
        'ACTIVE' { 
            if ($ConvertedHireDateDT -and $ConvertedHireDateDT -gt $NowRoundedToDay) {
                $status = 'hire'  # Active but hire date in future
            } else {
                $status = 'active'
            }
        }
        'EMPLOYED' { $status = 'active' }
        'WORKING' { $status = 'active' }
        'LEAVE' { $status = 'active' }
        'ABSENCE' { $status = 'active' }
        'SUSPENDED' { $status = 'active' }
        'INACTIVE' { $status = 'terminated' }
        'TERMINATED' { $status = 'terminated' }
        'ENDED' { $status = 'terminated' }
        default {
            # Fallback to date-based logic if status is unclear
            if ($ConvertedHireDateDT) {
                $daysUntilHire = ($ConvertedHireDateDT - $NowRoundedToDay).Days
                if ($daysUntilHire -gt $LcsRules.PreHireDays) {
                    $status = 'prehire'
                } elseif ($daysUntilHire -gt 0) {
                    $status = 'hire'
                } else {
                    $status = 'active'
                }
            } else {
                $status = 'unknown'
            }
        }
    }

    Write-Host "Prodensa Status Calculation for Employee $($Employee.EMPLOYEENUMBER): $status (System Status: $EmployeeStatus)"
    return $status
}

# ===========================================
# FACTORY FUNCTION
# ===========================================
function Get-EmployeeStatusBySource {
    param (
        [string]$SourceName,
        $Employee,
        $ConvertedHireDateDT,
        $NowRoundedToDay,
        $LcsRules,
        $EmployeeStartDate,
        $EmployeeStatus
    )
    
    switch ($SourceName) {
        "MCH" { 
            return Get-MCHEmployeeStatus -Employee $Employee -ConvertedHireDateDT $ConvertedHireDateDT -NowRoundedToDay $NowRoundedToDay -LcsRules $LcsRules -EmployeeStartDate $EmployeeStartDate -EmployeeStatus $EmployeeStatus
        }
        "Tress" { 
            return Get-TressEmployeeStatus -Employee $Employee -ConvertedHireDateDT $ConvertedHireDateDT -NowRoundedToDay $NowRoundedToDay -LcsRules $LcsRules -EmployeeStartDate $EmployeeStartDate -EmployeeStatus $EmployeeStatus
        }
        "Prodensa" { 
            return Get-ProdensaEmployeeStatus -Employee $Employee -ConvertedHireDateDT $ConvertedHireDateDT -NowRoundedToDay $NowRoundedToDay -LcsRules $LcsRules -EmployeeStartDate $EmployeeStartDate -EmployeeStatus $EmployeeStatus
        }
        default { 
            Write-Error "Unknown source: $SourceName"
            return "unknown"
        }
    }
}

# ===========================================
# TESTING FUNCTIONS (Optional)
# ===========================================
function Test-StatusCalculation {
    param (
        [string]$SourceName,
        [string]$EmployeeStatus,
        [DateTime]$HireDate,
        [DateTime]$TestDate = (Get-Date)
    )
    
    # Create mock employee for testing
    $mockEmployee = @{
        EMPLOYEENUMBER = "TEST123"
        EMPLOYEE_STATUS = $EmployeeStatus
        HIRE_DATE = $HireDate.ToString("MM-dd-yyyy")
    }
    
    # Get source config for testing
    Import-Module -Name "Final_SourceConfigurations.psm1" -Force
    $sourceConfig = Get-SourceConfig -SourceName $SourceName
    
    # Calculate status
    $status = Get-EmployeeStatusBySource -SourceName $SourceName -Employee $mockEmployee -ConvertedHireDateDT $HireDate -NowRoundedToDay $TestDate.Date -LcsRules $sourceConfig.LcsCalculationRules -EmployeeStartDate $HireDate.ToString("MM-dd-yyyy") -EmployeeStatus $EmployeeStatus
    
    Write-Host "Test Result for $SourceName:"
    Write-Host "  Employee Status: $EmployeeStatus"
    Write-Host "  Hire Date: $($HireDate.ToString('yyyy-MM-dd'))"
    Write-Host "  Test Date: $($TestDate.ToString('yyyy-MM-dd'))"
    Write-Host "  Calculated Status: $status"
    
    return $status
}

Export-ModuleMember -Function Get-EmployeeStatusBySource, Test-StatusCalculation