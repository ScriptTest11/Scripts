
    [Parameter(Mandatory=$true)]
    [string]$InputPath = "C:\Users\sagar\Desktop\Testing\test.xlsx"

    [Parameter(Mandatory=$true)]
    [string]$OutputPath = "C:\Users\sagar\Desktop\Testing\test_update.xlsx"

    [string]$Sheet1Name = 'Sheet1'
    [string]$Sheet2Name = 'Sheet2'

    # Header names (row 1)
    [string]$HeaderNameSheet1 = 'employeeid'
    [string]$HeaderNameSheet2 = 'employee_id'

    [string]$sourceName = 'Test'

# Ensure ImportExcel is available (no COM, no Excel needed)
if (-not (Get-Module -ListAvailable -Name ImportExcel)) {
    Write-Error "The ImportExcel module is required. Install it via: Install-Module ImportExcel -Scope CurrentUser"
    exit 1
}
Import-Module ImportExcel -ErrorAction Stop

function Get-ColumnIndexByHeader {
    param(
        [Parameter(Mandatory=$true)]$Worksheet,
        [Parameter(Mandatory=$true)][string]$HeaderName
    )
    if ($null -eq $Worksheet.Dimension) { return $null }
    $startRow = $Worksheet.Dimension.Start.Row
    $startCol = $Worksheet.Dimension.Start.Column
    $endCol   = $Worksheet.Dimension.End.Column

    for ($c = $startCol; $c -le $endCol; $c++) {
        $val = $Worksheet.Cells[$startRow, $c].Text
        if ([string]::IsNullOrWhiteSpace($val)) { continue }
        if ($val.Trim().ToLower() -eq $HeaderName.Trim().ToLower()) {
            return $c
        }
    }
    return $null
}

try {
    Write-Host "Starting... $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Write-Host "Input:  $InputPath"
    Write-Host "Output: $OutputPath"
    Write-Host "Sheets: Sheet1='$Sheet1Name' (header '$HeaderNameSheet1'), Sheet2='$Sheet2Name' (header '$HeaderNameSheet2')"

    if (-not (Test-Path -LiteralPath $InputPath)) {
        throw "Input file not found: $InputPath"
    }

    # Work on a copy so original is untouched
    Copy-Item -LiteralPath $InputPath -Destination $OutputPath -Force
    Write-Host "Copied input to output file."

    $pkg = Open-ExcelPackage -Path $OutputPath
    try {
        $ws1 = $pkg.Workbook.Worksheets[$Sheet1Name]
        $ws2 = $pkg.Workbook.Worksheets[$Sheet2Name]
        if ($null -eq $ws1) { throw "Worksheet not found: $Sheet1Name" }
        if ($null -eq $ws2) { throw "Worksheet not found: $Sheet2Name" }
        if ($null -eq $ws1.Dimension) { throw "$Sheet1Name is empty." }
        if ($null -eq $ws2.Dimension) { throw "$Sheet2Name is empty." }

        $colId1 = Get-ColumnIndexByHeader -Worksheet $ws1 -HeaderName $HeaderNameSheet1
        if (-not $colId1) { throw "Could not find header '$HeaderNameSheet1' on $Sheet1Name row 1." }

        $colId2 = Get-ColumnIndexByHeader -Worksheet $ws2 -HeaderName $HeaderNameSheet2
        if (-not $colId2) { throw "Could not find header '$HeaderNameSheet2' on $Sheet2Name row 1." }

        $startRow1 = $ws1.Dimension.Start.Row
        $endRow1   = $ws1.Dimension.End.Row
        $startRow2 = $ws2.Dimension.Start.Row
        $endRow2   = $ws2.Dimension.End.Row
        $endCol2   = $ws2.Dimension.End.Column

        $rows1 = [Math]::Max(0, $endRow1 - $startRow1)
        $rows2 = [Math]::Max(0, $endRow2 - $startRow2)
        Write-Host "$Sheet1Name data rows: $rows1; $Sheet2Name data rows: $rows2"

        # Keep IDs as text in the output
        $ws1.Column($colId1).Style.Numberformat.Format = '@'
        $ws2.Column($colId2).Style.Numberformat.Format = '@'

        # Build lookup set from Sheet1 IDs
        $ids = New-Object 'System.Collections.Generic.HashSet[string]'
        for ($r = $startRow1 + 1; $r -le $endRow1; $r++) {
            $txt = $ws1.Cells[$r, $colId1].Text.Trim()
            if (-not [string]::IsNullOrWhiteSpace($txt)) { [void]$ids.Add($txt) }
        }
        Write-Host "Collected unique IDs from $($Sheet1Name): $($ids.Count)"

        # Add new column isPresentHR at the end of Sheet2
        $newCol = $endCol2 + 1
        $ws2.Cells[$startRow2, $newCol].Value = 'isPresentHR'
        $ws2.Column($newCol).Style.Numberformat.Format = '@'
        Write-Host "Added 'isPresentHR' at column index $newCol."

        # Counters
        $processed = 0
        $matched   = 0
        $unmatched = 0
        $blank     = 0

        # Fill values for Sheet2 rows
        for ($r = $startRow2 + 1; $r -le $endRow2; $r++) {
            $idTxt2 = $ws2.Cells[$r, $colId2].Text.Trim()
            if ([string]::IsNullOrWhiteSpace($idTxt2)) {
                $ws2.Cells[$r, $newCol].Value = 'FALSE'
                $blank++
            } else {
                $present = $ids.Contains($idTxt2)
                $ws2.Cells[$r, $newCol].Value = if ($present) { 'TRUE' } else { 'FALSE' }
                if ($present) { $matched++ } else { $unmatched++ }
            }
            $processed++
        }

if (-not (Get-Command Get-ExcelColumnName -ErrorAction SilentlyContinue)) {
    function Get-ExcelColumnName {
        param([int]$Index)
        $div = $Index; $colName = ''
        while ($div -gt 0) {
            $mod = ($div - 1) % 26
            $colName = [char](65 + $mod) + $colName
            $div = [math]::Floor(($div - $mod) / 26)
        }
        return $colName
    }
}
# === BEGIN FIXED SUMMARY (robust Value/Text reads) ===

# === BEGIN AUTO-GROUPED SUMMARY ===

# Which column holds lifecycle/status?
$lcsHeader = 'lcs'   # set to your real header if different
$lcsCol = Get-ColumnIndexByHeader -Worksheet $ws2 -HeaderName $lcsHeader
if (-not $lcsCol) { throw "Could not find header '$lcsHeader' on $Sheet2Name row 1." }

# Count non-empty IDs in Sheet1 and Sheet2
$cntSheet1 = 0
for ($r = $startRow1 + 1; $r -le $endRow1; $r++) {
    $v = $ws1.Cells[$r, $colId1].Value
    $t = if ($null -ne $v) { [string]$v } else { $ws1.Cells[$r, $colId1].Text }
    if (-not [string]::IsNullOrWhiteSpace($t)) { $cntSheet1++ }
}

$cntSheet2 = 0
for ($r = $startRow2 + 1; $r -le $endRow2; $r++) {
    $v = $ws2.Cells[$r, $colId2].Value
    $t = if ($null -ne $v) { [string]$v } else { $ws2.Cells[$r, $colId2].Text }
    if (-not [string]::IsNullOrWhiteSpace($t)) { $cntSheet2++ }
}

# Normalize function for status text
function Normalize-Status {
    param([string]$s)
    if ([string]::IsNullOrWhiteSpace($s)) { return 'Other/Unknown' }
    $s = ($s -replace '\s+', ' ').Trim()

    # Canonicalize common variants
    $canonMap = @{
        '^(pre[\s\-]?hire)$'   = 'PreHire'
        '^hire$'               = 'Hire'
        '^active$'             = 'Active'
        '^(terminated|term)$'  = 'Terminated'
        '^(disabled|inactive)$'= 'Disabled'
    }
    foreach ($rx in $canonMap.Keys) {
        if ($s -imatch $rx) { return $canonMap[$rx] }
    }
    return $s  # keep unknowns by their cleaned text
}

# Tally by discovered statuses (not a fixed list)
$counts = @{}   # key -> @{HR=0; Missing=0}
$processedRows = 0
for ($r = $startRow2 + 1; $r -le $endRow2; $r++) {
    $rawLcs = $ws2.Cells[$r, $lcsCol].Value
    $lcTxt  = if ($null -ne $rawLcs) { [string]$rawLcs } else { $ws2.Cells[$r, $lcsCol].Text }
    $status = Normalize-Status $lcTxt

    $hrCell = $ws2.Cells[$r, $newCol]
    $val = $hrCell.Value
    $txt = $hrCell.Text
    $present = $false
    if ($val -is [bool]) {
        $present = [bool]$val
    } elseif ($val -is [string]) {
        $present = ($val.Trim().ToUpper() -eq 'TRUE')
    } elseif (-not [string]::IsNullOrWhiteSpace($txt)) {
        $present = ($txt.Trim().ToUpper() -eq 'TRUE')
    }

    if (-not $counts.ContainsKey($status)) {
        $counts[$status] = @{ HR = 0; Missing = 0 }
    }
    if ($present) {
    $counts[$status]['HR'] = ([int]$counts[$status]['HR']) + 1
} else {
    $counts[$status]['Missing'] = ([int]$counts[$status]['Missing']) + 1
}
    $processedRows++
}

# Order rows: preferred canonical order first (if present), then remaining statuses alphabetically
$preferred = @('PreHire','Hire','Active','Terminated','Disabled')
$presentPreferred = $preferred | Where-Object { $counts.ContainsKey($_) }
$others = $counts.Keys | Where-Object { $presentPreferred -notcontains $_ } | Sort-Object
$statusOrder = @($presentPreferred + $others)

# Compute totals
$totHR      = ($statusOrder | ForEach-Object { [int]$counts[$_].HR } | Measure-Object -Sum).Sum
$totMissing = ($statusOrder | ForEach-Object { [int]$counts[$_].Missing } | Measure-Object -Sum).Sum

# Rebuild Summary sheet
$existing = $pkg.Workbook.Worksheets['Summary']
if ($existing) { $pkg.Workbook.Worksheets.Delete($existing) }
$sum = $pkg.Workbook.Worksheets.Add('Summary')

# Top section
$sum.Cells[1,1].Value = $sourceName
$sum.Cells[2,1].Value = 'Total User in HR';        $sum.Cells[2,2].Value = $cntSheet1
$sum.Cells[3,1].Value = 'Total User in SailPoint'; $sum.Cells[3,2].Value = $cntSheet2
$sum.Cells[4,1].Value = 'Missing HR User';         $sum.Cells[4,2].Value = $totMissing
#$sum.Cells[5,1].Value = 'Difference (SP - HR)';    $sum.Cells[5,2].Value = ($cntSheet2 - $cntSheet1)
#$sum.Cells[6,1].Value = 'Rows tallied';            $sum.Cells[6,2].Value = $processedRows

# Headers
$sum.Cells[8,1].Value = 'SailPoint Analysis'
$sum.Cells[9,1].Value = 'Status'
$sum.Cells[9,2].Value = 'HR User'
$sum.Cells[9,3].Value = 'Missing HR User'
$sum.Cells[9,4].Value = 'Total'

# Rows
$rowStart = 11
$row = $rowStart
foreach ($s in $statusOrder) {
    $hr = [int]$counts[$s].HR
    $miss = [int]$counts[$s].Missing
    $sum.Cells[$row,1].Value = $s
    $sum.Cells[$row,2].Value = $hr
    $sum.Cells[$row,3].Value = $miss
    $sum.Cells[$row,4].Value = ($hr + $miss)
    $row++
}

# Totals row
$sum.Cells[$row,1].Value = 'Total'
$sum.Cells[$row,2].Value = $totHR
$sum.Cells[$row,3].Value = $totMissing
$sum.Cells[$row,4].Value = ($totHR + $totMissing)

# Formatting
$sum.Cells["A1:D1"].Style.Font.Bold = $true
$sum.Cells["A8:D9"].Style.Font.Bold = $true
$sum.Cells["A1:D$row"].AutoFitColumns()

# === END AUTO-GROUPED SUMMARY ===

        $pkg.Save()

        Write-Host "Processed: $processed row(s) from $Sheet2Name."
        Write-Host "Matched (TRUE):   $matched"
        Write-Host "Unmatched (FALSE): $unmatched"
        Write-Host "Blank IDs:        $blank"
        Write-Host "Done. Output written to: $OutputPath"
    }
    finally {
        if ($pkg) { try { $pkg.Dispose() } catch {} }
    }
}
catch {
    Write-Error $_.Exception.Message
    throw
}