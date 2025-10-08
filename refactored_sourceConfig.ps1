
Write-Host "[INFO] Loading HCM source configuration..."

$HCMConfig = @{
    # Source system identifier
    SourceName = "HCM"
    
    # Expected number of columns in CSV header
    HeaderCount = 71
    Write-Host "[DEBUG] HCM Header Count: 71"
    
    # Date format used in CSV file (Month-Day-Year)
    DateFormat = "MM-dd-yyyy"
    Write-Host "[DEBUG] HCM Date Format: MM-dd-yyyy"
    
    # Validation processing mode
    # TRUE: Only copy file to processing folder if all validations pass (strict mode)
    # FALSE: Always copy file regardless of validation results (non-strict mode)
    processValidation = $true
    Write-Host "[DEBUG] HCM Process Validation Mode: STRICT (true)"
    
    # Source CSV filename to process
    SourceFileName = "RHEEM_SAILPOINT_RPT_V004.csv"
    Write-Host "[DEBUG] HCM Source File: RHEEM_SAILPOINT_RPT_V004.csv"
    
    # Field name for hire date in CSV
    HireDate = "HIRE_DATE"
    
    # Field name for termination date in CSV
    TermDate = "TERMINATION_DATE"
    Write-Host "[DEBUG] HCM Date Fields: HIRE_DATE, TERMINATION_DATE"
    
    # --------------------------------------------------------------------------------
    # MANDATORY FIELDS
    # PURPOSE: Fields that must be populated for non-terminated employees
    # IMPACT: Employees missing these fields will be flagged in validation report
    # --------------------------------------------------------------------------------
    MandatoryFields = @(
        "EMPLOYEENUMBER",        # Unique employee identifier
        "LAST_NAME",             # Employee last name
        "FIRST_NAME",            # Employee first name
        "COUNTRY",               # Employee country
        "DIVISION",              # Business division
        "BUSINESS_UNIT",         # Business unit assignment
        "DEPARTMENT",            # Department name
        "BSV_CCL_DEPT",          # BSV CCL department code
        "PRIMARY_MANAGER",       # Manager name
        "SALARY___HOURLY",       # Pay type classification
        "HIRE_DATE",             # Employee hire date
        "EMPLOYEE_STATUS",       # Current employment status
        "EFFECTIVE_START_DATE",  # Assignment effective start date
        "AD_SYNC_LIST",          # Active Directory sync list
        "AD_DONOTSYNC_LIST"      # Active Directory do not sync list
    )
    Write-Host "[DEBUG] HCM Mandatory Fields Count: $($HCMConfig.MandatoryFields.Count)"
    
    # --------------------------------------------------------------------------------
    # HEADER FIELDS
    # PURPOSE: Complete list of expected columns in CSV file
    # IMPACT: File validation will fail if any of these headers are missing
    # --------------------------------------------------------------------------------
    HeaderFields = @(
        # Employee Identification
        "EMPLOYEENUMBER",                      # Unique employee ID
        "LAST_NAME",                           # Last name
        "FIRST_NAME",                          # First name
        "MIDDLE_NAME",                         # Middle name
        "PREFERRED_NAME",                      # Preferred first name
        "PREFERRED_LAST_NAME",                 # Preferred last name
        "DISPLAY_NAME",                        # Display name
        "USER_NAME",                           # System username
        "USER_GUID",                           # Global unique identifier
        
        # Location Information
        "COUNTRY",                             # Country code
        "COUNTRY_CODE",                        # ISO country code
        "COUNTRY_DESCRIPTION",                 # Country full name
        "WORK_LOCATION_NAME",                  # Work location name
        "WORK_LOCATION_CODE",                  # Work location code
        "WORK_LOCATION_ADDRESS",               # Physical address
        "WORK_LOCATION_CITY",                  # City
        "WORK_LOCATION_STATE",                 # State/Province
        "WORK_LOCATION_ZIP",                   # Postal code
        "LOCATION_CODE",                       # Location code
        "LOCATION_ID",                         # Location identifier
        "PENDING_LOCATION_CODE",               # Future location code
        "WORKPLACE_LOCATION",                  # Workplace location
        "LEGISLATION_CODE",                    # Legal jurisdiction code
        
        # Organizational Structure
        "DIVISION",                            # Division name
        "DIVISION_CODE",                       # Division code
        "BUSINESS_UNIT",                       # Business unit name
        "BU_CODE",                             # Business unit code
        "DEPARTMENT",                          # Department name
        "DEPT_CODE",                           # Department code
        "BSV_CCL_DEPT",                        # BSV CCL department
        "LEGAL_EMPLOYER",                      # Legal employer entity
        
        # Job Information
        "JOB_TITLE",                           # Job title
        "JOB_CODE",                            # Job code
        "JOB_FAMILY",                          # Job family name
        "JOB_FAMILY_CODE",                     # Job family code
        "JOB_SUB_FAMILY",                      # Job sub-family name
        "JOB_SUB_FAMILY_CODE",                 # Job sub-family code
        "CAREER_LEVEL",                        # Career level
        "CAREER_LEVEL_CODE",                   # Career level code
        "CAREER_STREAM",                       # Career stream
        "CAREER_STREAM_CODE",                  # Career stream code
        "GRADE",                               # Job grade
        "SALARY_GRADE",                        # Salary grade
        
        # Management & Reporting
        "PRIMARY_MANAGER",                     # Manager name
        "PRIMARY_MANAGER_EMPLOYEE_NUMBER",     # Manager employee number
        "SUPERVISOR_MANAGER_TYPE",             # Supervisor type
        
        # Compensation & Employment Type
        "SALARY___HOURLY",                     # Pay classification
        "FT_OR_PT",                            # Full-time or Part-time
        "WORKER_TYPE",                         # Worker type classification
        "SHIFT_CODE",                          # Work shift code
        "UNION_CODE",                          # Union membership code
        
        # Dates
        "HIRE_DATE",                           # Original hire date
        "LAST_HIRE_DATE",                      # Most recent hire date
        "ENTERPRISE_DATE",                     # Enterprise seniority date
        "EFFECTIVE_START_DATE",                # Assignment start date
        "EFFECTIVE_END_DATE",                  # Assignment end date
        "TERMINATION_DATE",                    # Termination date
        
        # Assignment Information
        "ASSIGNMENT_ID",                       # Assignment identifier
        "ASSIGNMENT_NAME",                     # Assignment name
        "ASSIGNMENT_NUMBER",                   # Assignment number
        "ASSIGNMENT_STATUS_TYPE",              # Assignment status
        
        # Status Information
        "EMPLOYEE_STATUS",                     # Employment status
        "SYSTEM_PERSON_TYPE",                  # System person type
        "ACTION_CODE",                         # HR action code
        "ACTION_REASON_CODE",                  # Action reason code
        
        # Contact Information
        "WORK_EMAIL",                          # Work email address
        "EMAIL_ADDRESS_ID",                    # Email address ID
        "WORK_TELEPHONE",                      # Work phone number
        "WORK_MOBILE",                         # Work mobile number
        
        # Integration Fields
        "AD_SYNC_LIST",                        # Active Directory sync flag
        "AD_DONOTSYNC_LIST"                    # Active Directory exclusion flag
    )
    Write-Host "[DEBUG] HCM Header Fields Count: $($HCMConfig.HeaderFields.Count)"
    
   
    EmployeeNameFields = @{
        FirstName = "FIRST_NAME"               # CSV column for first name
        LastName = "LAST_NAME"                 # CSV column for last name
    }
    Write-Host "[DEBUG] HCM Name Fields Configured: FIRST_NAME, LAST_NAME"
    
   
    LcsCalculationRules = @{
       
        PreHireDays = 14
        Write-Host "[DEBUG] HCM Pre-hire Window: 14 days"
        
      
        TerminationThreshold = 20
        Write-Host "[DEBUG] HCM Termination Spike Threshold: 20 employees"
       
        StatusMappings = @{

            Active = @(
                "Active - Regular",            # Regular full-time/part-time active
                "Active - Temporary",          # Temporary active employee
                "Active - Contract"            # Contract worker active
            )
            
            # Leave of absence and suspension status codes
            # Note: These are treated as "active" in lifecycle calculations
            LeaveOfAbsence = @(
                "Leave of Absence",            # On approved leave
                "Suspended - Payroll Eligible", # Suspended but receiving pay
                "Suspended - No Payroll"       # Suspended without pay
            )
            
            # Inactive and layoff status codes
            Inactive = @(
                "Inactive",                    # General inactive status
                "Layoff"                       # Laid off but not terminated
            )
        }
        Write-Host "[DEBUG] HCM Status Mappings Configured (Active, LeaveOfAbsence, Inactive)"
    }
}

Write-Host "[SUCCESS] HCM configuration loaded successfully"

Write-Host "[INFO] Tress source configuration - PLACEHOLDER (not yet implemented)"

Write-Host "[INFO] Prodensa source configuration - PLACEHOLDER (not yet implemented)"

function Get-SourceConfig {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet("HCM", "Tress", "Prodensa")]
        [string]$SourceName
    )
    
    Write-Host "[INFO] Retrieving configuration for source: $SourceName"
    
    # Route to appropriate configuration based on source name
    switch ($SourceName) {
        "HCM" { 
            Write-Host "[SUCCESS] Returning HCM configuration"
            return $HCMConfig 
        }
        "Tress" { 
            Write-Host "[WARNING] Tress configuration requested but not yet implemented"
            return $TressConfig 
        }
        "Prodensa" { 
            Write-Host "[WARNING] Prodensa configuration requested but not yet implemented"
            return $ProdensaConfig 
        }
        default { 
            Write-Host "[ERROR] Unknown source system: $SourceName"
            Write-Error "Unknown source: $SourceName"
            return $null
        }
    }
}


function Get-AllSourceConfigs {
    Write-Host "[INFO] Retrieving all source configurations..."
    
    $allConfigs = @{
        HCM = $HCMConfig
        Tress = $TressConfig
        Prodensa = $ProdensaConfig
    }
    
    Write-Host "[SUCCESS] Returned configurations for: $($allConfigs.Keys -join ', ')"
    return $allConfigs
}

function Validate-SourceConfig {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [hashtable]$Config
    )
    
    Write-Host "`n[INFO] ========================================"
    Write-Host "[INFO] Starting configuration validation..."
    Write-Host "[INFO] Source: $($Config.SourceName)"
    Write-Host "[INFO] ========================================"
    
    # Define required configuration keys
    $requiredKeys = @(
        "SourceName",              # Source system identifier
        "HeaderCount",             # Expected number of CSV columns
        "DateFormat",              # Date format string
        "processValidation",       # Validation processing mode
        "MandatoryFields",         # List of required fields
        "HeaderFields",            # List of expected headers
        "EmployeeNameFields",      # Name field mappings
        "LcsCalculationRules"      # Lifecycle calculation rules
    )
    
    Write-Host "[INFO] Checking for required configuration keys..."
    Write-Host "[DEBUG] Required keys: $($requiredKeys.Count)"
    
    # Validate each required key exists
    $missingKeys = @()
    foreach ($key in $requiredKeys) {
        if (-not $Config.ContainsKey($key)) {
            $missingKeys += $key
            Write-Host "[ERROR] Missing required configuration key: $key"
        } else {
            Write-Host "[SUCCESS] Key present: $key"
        }
    }
    
    # If any keys are missing, configuration is invalid
    if ($missingKeys.Count -gt 0) {
        Write-Host "`n[ERROR] Configuration validation FAILED"
        Write-Host "[ERROR] Missing keys: $($missingKeys -join ', ')"
        return $false
    }
    
    Write-Host "[SUCCESS] All required keys present"

    Write-Host "`n[INFO] Validating mandatory fields are present in header fields..."
    $invalidMandatoryFields = @()
    
    foreach ($mandatoryField in $Config.MandatoryFields) {
        if ($Config.HeaderFields -notcontains $mandatoryField) {
            $invalidMandatoryFields += $mandatoryField
            Write-Host "[WARNING] Mandatory field '$mandatoryField' not found in header fields for $($Config.SourceName)"
        }
    }
    
    if ($invalidMandatoryFields.Count -gt 0) {
        Write-Host "[WARNING] Some mandatory fields are not in header fields list"
        Write-Host "[WARNING] This may cause validation issues"
        Write-Host "[WARNING] Fields: $($invalidMandatoryFields -join ', ')"
    } else {
        Write-Host "[SUCCESS] All mandatory fields are present in header fields"
    }
    
    # --------------------------------------------------------------------------------
    # Additional validation checks
    # --------------------------------------------------------------------------------
    Write-Host "`n[INFO] Performing additional validation checks..."
    
    # Check HeaderCount is positive
    if ($Config.HeaderCount -le 0) {
        Write-Host "[ERROR] HeaderCount must be positive, found: $($Config.HeaderCount)"
        return $false
    }
    Write-Host "[SUCCESS] HeaderCount is valid: $($Config.HeaderCount)"
    
    # Check DateFormat is not empty
    if ([string]::IsNullOrWhiteSpace($Config.DateFormat)) {
        Write-Host "[ERROR] DateFormat cannot be empty"
        return $false
    }
    Write-Host "[SUCCESS] DateFormat is valid: $($Config.DateFormat)"
    
    # Check processValidation is boolean
    if ($Config.processValidation -isnot [bool]) {
        Write-Host "[ERROR] processValidation must be boolean, found: $($Config.processValidation.GetType().Name)"
        return $false
    }
    Write-Host "[SUCCESS] processValidation is valid: $($Config.processValidation)"
    
    # Check MandatoryFields is not empty
    if ($Config.MandatoryFields.Count -eq 0) {
        Write-Host "[WARNING] No mandatory fields defined"
    } else {
        Write-Host "[SUCCESS] Mandatory fields defined: $($Config.MandatoryFields.Count)"
    }
    
    # Check HeaderFields is not empty
    if ($Config.HeaderFields.Count -eq 0) {
        Write-Host "[ERROR] HeaderFields cannot be empty"
        return $false
    }
    Write-Host "[SUCCESS] Header fields defined: $($Config.HeaderFields.Count)"
    
    # --------------------------------------------------------------------------------
    # Validation summary
    # --------------------------------------------------------------------------------
    Write-Host "`n[INFO] ========================================"
    Write-Host "[SUCCESS] Configuration validation PASSED"
    Write-Host "[INFO] Source: $($Config.SourceName)"
    Write-Host "[INFO] Header Count: $($Config.HeaderCount)"
    Write-Host "[INFO] Mandatory Fields: $($Config.MandatoryFields.Count)"
    Write-Host "[INFO] Header Fields: $($Config.HeaderFields.Count)"
    Write-Host "[INFO] Process Validation: $($Config.processValidation)"
    Write-Host "[INFO] ========================================"
    
    return $true
}

# ================================================================================
# MODULE EXPORTS
# Export configuration variables and functions for use by other modules
# ================================================================================
Write-Host "`n[INFO] Exporting module members..."
Write-Host "[DEBUG] Exported variables: HCMConfig, TressConfig, ProdensaConfig"
Write-Host "[DEBUG] Exported functions: Get-SourceConfig, Get-AllSourceConfigs, Validate-SourceConfig"

Export-ModuleMember -Variable HCMConfig, TressConfig, ProdensaConfig
Export-ModuleMember -Function Get-SourceConfig, Get-AllSourceConfigs, Validate-SourceConfig

Write-Host "[SUCCESS] Source configuration module loaded successfully"
