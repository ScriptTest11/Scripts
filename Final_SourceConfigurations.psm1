# Source Configuration Objects for Multi-Source HR Validation System
# Final Version with all features

# ===========================================
# MCH SOURCE CONFIGURATION
# ===========================================
$MCHConfig = @{
    SourceName = "MCH"
    HeaderCount = 70
    DateFormat = "MM-dd-yyyy"
    processValidation = $true    # Only copy file if validation passes
    
    MandatoryFields = @(
        "EMPLOYEENUMBER", "LAST_NAME", "FIRST_NAME", "COUNTRY", "DIVISION", 
        "BUSINESS_UNIT", "DEPARTMENT", "BSV_CCL_DEPT", "PRIMARY_MANAGER", 
        "SALARY___HOURLY", "HIRE_DATE", "EMPLOYEE_STATUS", "EFFECTIVE_START_DATE"
    )
    
    HeaderFields = @(
        "EMPLOYEENUMBER", "LAST_NAME", "FIRST_NAME", "COUNTRY", "WORK_LOCATION_NAME", 
        "WORK_LOCATION_CODE", "WORK_LOCATION_ADDRESS", "WORK_LOCATION_CITY", 
        "WORK_LOCATION_STATE", "WORK_LOCATION_ZIP", "DIVISION", "DIVISION_CODE", 
        "BUSINESS_UNIT", "BU_CODE", "JOB_TITLE", "JOB_CODE", "DEPARTMENT", "DEPT_CODE", 
        "BSV_CCL_DEPT", "PRIMARY_MANAGER", "PRIMARY_MANAGER_EMPLOYEE_NUMBER", 
        "JOB_FAMILY", "JOB_FAMILY_CODE", "JOB_SUB_FAMILY", "JOB_SUB_FAMILY_CODE", 
        "CAREER_LEVEL", "CAREER_LEVEL_CODE", "SALARY___HOURLY", "SALARY_GRADE", 
        "FT_OR_PT", "HIRE_DATE", "WORKER_TYPE", "LAST_HIRE_DATE", "ENTERPRISE_DATE", 
        "ASSIGNMENT_ID", "EMPLOYEE_STATUS", "ACTION_CODE", "ACTION_REASON_CODE", 
        "COUNTRY_CODE", "COUNTRY_DESCRIPTION", "WORK_EMAIL", "EFFECTIVE_START_DATE", 
        "EFFECTIVE_END_DATE", "ASSIGNMENT_NAME", "ASSIGNMENT_NUMBER", 
        "ASSIGNMENT_STATUS_TYPE", "LOCATION_CODE", "PENDING_LOCATION_CODE", 
        "SYSTEM_PERSON_TYPE", "DISPLAY_NAME", "USER_NAME", "LEGISLATION_CODE", 
        "LEGAL_EMPLOYER", "LOCATION_ID", "SUPERVISOR_MANAGER_TYPE", "SHIFT_CODE", 
        "AD_SYNC_LIST", "AD_DONOTSYNC_LIST", "EMAIL_ADDRESS_ID", "USER_GUID", 
        "WORK_TELEPHONE", "UNION_CODE", "TERMINATION_DATE", "MIDDLE_NAME", 
        "WORK_MOBILE", "CAREER_STREAM", "CAREER_STREAM_CODE", "PREFERRED_NAME", 
        "WORKPLACE_LOCATION", "PREFERRED_LAST_NAME"
    )
    
    EmployeeNameFields = @{
        FirstName = "FIRST_NAME"
        LastName = "LAST_NAME"
    }
    
    LcsCalculationRules = @{
        PreHireDays = 14
        TerminationThreshold = 20    # Stop processing if >20 more terminations than yesterday
        StatusMappings = @{
            Active = @("Active - Regular", "Active - Temporary", "Active - Contract")
            LeaveOfAbsence = @("Leave of Absence", "Suspended - Payroll Eligible", "Suspended - No Payroll")
            Inactive = @("Inactive", "Layoff")
        }
    }
}

# ===========================================
# TRESS SOURCE CONFIGURATION
# ===========================================
$TressConfig = @{
    SourceName = "Tress"
    HeaderCount = 65
    DateFormat = "dd-MM-yyyy"
    processValidation = $false   # Always copy file regardless of validation
    
    MandatoryFields = @(
        "EMPLOYEENUMBER", "PREFERRED_LAST_NAME", "PREFERRED_FIRST_NAME", "COUNTRY", 
        "DIVISION", "BUSINESS_UNIT", "DEPARTMENT", "PRIMARY_MANAGER", 
        "SALARY___HOURLY", "HIRE_DATE", "EMPLOYEE_STATUS", "EFFECTIVE_START_DATE"
    )
    
    HeaderFields = @(
        "EMPLOYEENUMBER", "PREFERRED_LAST_NAME", "PREFERRED_FIRST_NAME", "COUNTRY", 
        "WORK_LOCATION_NAME", "WORK_LOCATION_CODE", "DIVISION", "DIVISION_CODE", 
        "BUSINESS_UNIT", "BU_CODE", "JOB_TITLE", "JOB_CODE", "DEPARTMENT", "DEPT_CODE", 
        "BSV_CCL_DEPT", "PRIMARY_MANAGER", "PRIMARY_MANAGER_EMPLOYEE_NUMBER", 
        "JOB_FAMILY", "JOB_FAMILY_CODE", "CAREER_LEVEL", "CAREER_LEVEL_CODE", 
        "SALARY___HOURLY", "SALARY_GRADE", "FT_OR_PT", "HIRE_DATE", "WORKER_TYPE", 
        "ASSIGNMENT_ID", "EMPLOYEE_STATUS", "ACTION_CODE", "ACTION_REASON_CODE", 
        "COUNTRY_CODE", "WORK_EMAIL", "EFFECTIVE_START_DATE", "EFFECTIVE_END_DATE", 
        "ASSIGNMENT_NAME", "ASSIGNMENT_NUMBER", "LOCATION_CODE", "SYSTEM_PERSON_TYPE", 
        "DISPLAY_NAME", "USER_NAME", "LEGISLATION_CODE", "LEGAL_EMPLOYER", 
        "LOCATION_ID", "SUPERVISOR_MANAGER_TYPE", "EMAIL_ADDRESS_ID", "USER_GUID", 
        "WORK_TELEPHONE", "UNION_CODE", "TERMINATION_DATE", "MIDDLE_NAME", 
        "WORK_MOBILE", "CAREER_STREAM", "CAREER_STREAM_CODE", "WORKPLACE_LOCATION"
    )
    
    EmployeeNameFields = @{
        FirstName = "PREFERRED_FIRST_NAME"
        LastName = "PREFERRED_LAST_NAME"
    }
    
    LcsCalculationRules = @{
        PreHireDays = 10
        TerminationThreshold = 15    # Different threshold for Tress
        StatusMappings = @{
            Active = @("Active", "Active - Regular", "Active - Temporary")
            LeaveOfAbsence = @("Leave", "Medical Leave", "Personal Leave")
            Inactive = @("Inactive", "Terminated", "Resigned")
        }
    }
}

# ===========================================
# PRODENSA SOURCE CONFIGURATION
# ===========================================
$ProdensaConfig = @{
    SourceName = "Prodensa"
    HeaderCount = 55
    DateFormat = "yyyy-MM-dd"
    processValidation = $true    # Only copy file if validation passes
    
    MandatoryFields = @(
        "EMPLOYEENUMBER", "Preferred_Last_Name", "Preferred_First_Name", "COUNTRY", 
        "DIVISION", "BUSINESS_UNIT", "DEPARTMENT", "PRIMARY_MANAGER", 
        "SALARY_HOURLY", "HIRE_DATE", "EMPLOYEE_STATUS", "EFFECTIVE_START_DATE"
    )
    
    HeaderFields = @(
        "EMPLOYEENUMBER", "Preferred_Last_Name", "Preferred_First_Name", "COUNTRY", 
        "WORK_LOCATION_NAME", "DIVISION", "DIVISION_CODE", "BUSINESS_UNIT", "BU_CODE", 
        "JOB_TITLE", "JOB_CODE", "DEPARTMENT", "DEPT_CODE", "PRIMARY_MANAGER", 
        "PRIMARY_MANAGER_EMPLOYEE_NUMBER", "JOB_FAMILY", "JOB_FAMILY_CODE", 
        "CAREER_LEVEL", "CAREER_LEVEL_CODE", "SALARY_HOURLY", "SALARY_GRADE", 
        "FT_OR_PT", "HIRE_DATE", "WORKER_TYPE", "ASSIGNMENT_ID", "EMPLOYEE_STATUS", 
        "ACTION_CODE", "COUNTRY_CODE", "WORK_EMAIL", "EFFECTIVE_START_DATE", 
        "EFFECTIVE_END_DATE", "ASSIGNMENT_NAME", "LOCATION_CODE", "SYSTEM_PERSON_TYPE", 
        "DISPLAY_NAME", "USER_NAME", "LEGAL_EMPLOYER", "LOCATION_ID", 
        "EMAIL_ADDRESS_ID", "USER_GUID", "WORK_TELEPHONE", "TERMINATION_DATE", 
        "MIDDLE_NAME", "WORK_MOBILE", "CAREER_STREAM", "CAREER_STREAM_CODE", 
        "WORKPLACE_LOCATION"
    )
    
    EmployeeNameFields = @{
        FirstName = "Preferred_First_Name"
        LastName = "Preferred_Last_Name"
    }
    
    LcsCalculationRules = @{
        PreHireDays = 21
        TerminationThreshold = 30    # Higher threshold for Prodensa
        StatusMappings = @{
            Active = @("ACTIVE", "EMPLOYED", "WORKING")
            LeaveOfAbsence = @("LEAVE", "ABSENCE", "SUSPENDED")
            Inactive = @("INACTIVE", "TERMINATED", "ENDED")
        }
    }
}

# ===========================================
# CONFIGURATION HELPER FUNCTIONS
# ===========================================

function Get-SourceConfig {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet("MCH", "Tress", "Prodensa")]
        [string]$SourceName
    )
    
    switch ($SourceName) {
        "MCH" { return $MCHConfig }
        "Tress" { return $TressConfig }
        "Prodensa" { return $ProdensaConfig }
        default { 
            Write-Error "Unknown source: $SourceName"
            return $null
        }
    }
}

function Get-AllSourceConfigs {
    return @{
        MCH = $MCHConfig
        Tress = $TressConfig
        Prodensa = $ProdensaConfig
    }
}

function Validate-SourceConfig {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [hashtable]$Config
    )
    
    $requiredKeys = @("SourceName", "HeaderCount", "DateFormat", "processValidation", "MandatoryFields", "HeaderFields", "EmployeeNameFields", "LcsCalculationRules")
    
    foreach ($key in $requiredKeys) {
        if (-not $Config.ContainsKey($key)) {
            Write-Error "Missing required configuration key: $key"
            return $false
        }
    }
    
    # Validate that mandatory fields are subset of header fields
    foreach ($mandatoryField in $Config.MandatoryFields) {
        if ($Config.HeaderFields -notcontains $mandatoryField) {
            Write-Warning "Mandatory field '$mandatoryField' not found in header fields for $($Config.SourceName)"
        }
    }
    
    Write-Host "Configuration validation passed for $($Config.SourceName)"
    return $true
}

# Export configurations and functions
Export-ModuleMember -Variable MCHConfig, TressConfig, ProdensaConfig
Export-ModuleMember -Function Get-SourceConfig, Get-AllSourceConfigs, Validate-SourceConfig