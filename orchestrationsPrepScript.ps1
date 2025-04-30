
# Import the required modules
Import-Module -Name ImportExcel

# Specify the path to the Excel file
$excelFilePath = "C:\Users\Hauenstein Alex\ETL Database Objects.xlsx"

# Specify the path to the file containing TABLE_NAME and PRIMARY_KEY_COLUMN
$primaryKeyFilePath = "C:\Users\Hauenstein Alex\primaryKeys.txt"

# Read the Excel file
try {
    $excelData = Import-Excel -Path $excelFilePath
}
catch {
    Write-Host "Error reading the Excel file: $_"
    return
}

# Read the CSV file containing TABLE_NAME and PRIMARY_KEY_COLUMN
try {
    $primaryKeyData = Import-Csv -Path $primaryKeyFilePath
}
catch {
    Write-Host "Error reading the CSV file: $_"
    return
}


try {
    # Process the joined data and add the 'PRIMARY_KEY_COLUMN' to the output
    $processedData = $excelData | foreach {
        $column1 = $_.Table -replace '^.*?_', '' -replace '[-. ]', '_'
        $column2 = $_.Def   -replace "(?is)^.*?(SELECT)", 'SELECT' -ireplace 'ä', 'ae' -ireplace 'ü', 'ue' -ireplace 'ö', 'oe' -replace '(?i)(\bFROM\b)', ', [CREATEDDATE], [MODIFIEDDATE] $1' #-replace '--', '/*' #-replace ",(?=.*\*/)", "*/,"        
        $column2 = $column2 -replace '--', '/* --' -replace 'AS \[\]', 'AS [] */'
        $column21= " WHERE [FIRMENNR] IN ({{CompanyNo}}) AND COALESCE(MODIFIEDDATE, CREATEDDATE) > ''{{LoadTimestamp}}'''),"
        $column3 = "N/A - haui"
        
        # Input string with special characters
# $inputString = "Mädchen"
 $replacedString = $column2 -replace 'ä', 'ae'
 Write-Host $replacedString


        # Process the data or perform any other operations
        [PSCustomObject]@{
            PipelineName        = "('THO_111_Bronze_PL_RecyRepl'"
            SourceSchema        = "'dbo'"
            SourceTable         = "'$column1'"
            SourceKeyColumn     = "'$column3'"
            SinkTableName       = "'RECY_$column1'"
            LoadType            = "'incremental'"
            BatchLoadDatetime   = "'1970-01-01T00:00:00'"
            SqlStatement        = "'$column2"+"$column21"
        }
    }
    # Write-Host "## 1 :", $column21

    # Write the data to a text file
    $outputFilePath = "C:\Users\Hauenstein Alex\OutputSQL.txt"
    $header = "PipelineName;SourceSchema;SourceTable;SourceKeyColumn;SinkTableName;LoadType;BatchLoadDatetime;SqlStatement"
    $header | Set-Content -Path $outputFilePath -Encoding UTF8
    $processedData | Select-Object -Property PipelineName, SourceSchema, SourceTable, SourceKeyColumn, SinkTableName, LoadType, BatchLoadDatetime, SqlStatement | ForEach-Object {
        $_.PipelineName + "; " + $_.SourceSchema + "; " + $_.SourceTable + "; " + $_.SourceKeyColumn + "; " + $_.SinkTableName + "; " + $_.LoadType + "; " + $_.BatchLoadDatetime + "; " + $_.SqlStatement
    } | Add-Content -Path $outputFilePath -Encoding UTF8

    
 #   Write-Host "Data written to file: $outputFilePath"

    # Display the processed data
    # $processedData | Format-Table -AutoSize
}
catch {
    Write-Host "Error processing the data: $_"
}