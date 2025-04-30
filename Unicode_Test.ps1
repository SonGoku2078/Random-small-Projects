$inputString = "[Gültig bis]"
$replacedString = $inputString -replace '(?<=\[)(.*?)(?=\])', { $matches[0] -replace '\s', '_' }

Write-Output $replacedString