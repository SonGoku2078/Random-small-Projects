# Specify the path to the text file
$textFilePath = "C:\Users\Hauenstein Alex\Test_Umlaute.txt"

# Read the content of the text file
$content = Get-Content -Path $textFilePath

# Process each row and replace characters
$processedData = $content | ForEach-Object {
    $replacedRow = $_           -replace '\x00E4', '4'  # Replace "ä" with "4"
    $replacedRow = $replacedRow -replace '\x00F6', '4'  # Replace "ö" with "4"
    $replacedRow = $replacedRow -replace '\x00FC', '4'  # Replace "ü" with "4"
    [PSCustomObject]@{
        TableRow = $replacedRow
    }
}

# Specify the path for the new text file
$newTextFilePath = "C:\Users\Hauenstein Alex\Updated_TextFile.txt"

# Write the processed content to the new text file
$processedData | ForEach-Object {
    # Output the content
    Write-Host $_.TableRow

    $_.TableRow | Out-File -Append -FilePath $newTextFilePath
}



