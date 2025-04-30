# CSV-Datei einlesen
$csvFile = "C:\Users\SonGoku78\Downloads\Birthdays_Export.csv"  # Pfad zu deiner CSV-Datei
$icsFile = "C:\Users\SonGoku78\Downloads\Birthdays_Cal.ics"  # Zielpfad für die ICS-Datei

# ICS Header
$icsContent = "BEGIN:VCALENDAR`nVERSION:2.0`nPRODID:-//Your Company//NONSGML v1.0//EN`n"

# CSV-Datei einlesen
$csvData = Import-Csv -Path $csvFile -Delimiter ";"

# Aktuelles Jahr und die nächsten 5 Jahre
$currentYear = (Get-Date).Year
$yearsToGenerate = 5  # Generiere Ereignisse für die nächsten 5 Jahre

# Für jedes Event im CSV eine ICS-Ereignis hinzufügen
foreach ($row in $csvData) {
    $eventTitle = $row.Name
    $eventDate = $row.Birthday
    $eventType = $row.'Type (Birthday=B, Anniversary=A)'

    # Ereignis für jedes Jahr generieren (aktuell + 4 weitere Jahre)
    for ($i = 0; $i -lt $yearsToGenerate; $i++) {
        # Jahr anpassen (z.B. 2023, 2024, ...)
        $eventYear = $currentYear + $i
        $startDateWithYear = $eventDate -replace "^\d{4}", $eventYear
        $startTime = [datetime]::ParseExact($startDateWithYear, 'yyyy-MM-dd', $null)

        # ICS-Ereignisblock für jedes Jahr (ganztägig)
        $icsContent += "BEGIN:VEVENT`n"
        $icsContent += "SUMMARY:$eventTitle`n"
        $icsContent += "DTSTART;VALUE=DATE:" + $startTime.ToString('yyyyMMdd') + "`n"  # Ganztägiges Event
        $icsContent += "DTEND;VALUE=DATE:" + $startTime.AddDays(1).ToString('yyyyMMdd') + "`n"  # Endet am nächsten Tag, auch ganztägig
        $icsContent += "DESCRIPTION:$eventType`n"
        $icsContent += "LOCATION:Online`n"  # Optional: Wenn keine Location, dann Online als Standard
        $icsContent += "END:VEVENT`n"
    }
}

# ICS Footer
$icsContent += "END:VCALENDAR"

# ICS-Datei speichern
$icsContent | Out-File -FilePath $icsFile -Encoding UTF8

Write-Host "ICS-Datei wurde erfolgreich erstellt: $icsFile"

