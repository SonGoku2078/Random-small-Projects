# Spotify OAuth Konfiguration
$clientId = "ce60943b59c04bd6b5e017f01f570cca"
$clientSecret = "3b27d3cff4584f0db326a2ccc73ac894"
$redirectUri = "https://example.com/callback"  # Muss in der Spotify Developer Console eingetragen sein
$scope = "playlist-read-private playlist-read-collaborative user-library-read"

# Öffne Spotify Login im Browser
$authUrl = "https://accounts.spotify.com/authorize?client_id=$clientId&response_type=code&redirect_uri=$redirectUri&scope=$scope"
Start-Process $authUrl
Write-Host "Bitte logge dich im Browser ein. Danach kopiere den 'code' Parameter aus der URL (?code=...)..." -ForegroundColor Yellow
$authCode = Read-Host "🔁 Füge hier den Spotify-Code aus der URL ein"

# Tausche Code gegen Access Token
$authBytes = [System.Text.Encoding]::ASCII.GetBytes("$clientId`:$clientSecret")
$authHeader = [Convert]::ToBase64String($authBytes)

try {
    $response = Invoke-RestMethod -Method POST -Uri "https://accounts.spotify.com/api/token" `
        -Headers @{ Authorization = "Basic $authHeader" } `
        -Body @{
            grant_type    = "authorization_code"
            code          = $authCode
            redirect_uri  = $redirectUri
        }

    $accessToken = $response.access_token
} catch {
    Write-Error "❌ Fehler beim Holen des Access Tokens: $($_.Exception.Message)"
    return
}

if (-not $accessToken) {
    Write-Error "❌ Kein Access Token erhalten – war der 'code' vielleicht schon benutzt?"
    return
}

Write-Host "✅ Access Token erhalten!"

# === PLAYLISTS ABFRAGEN ===
$headers = @{ Authorization = "Bearer $accessToken" }
$allPlaylists = @()
$offset = 0

try {
    do {
        $url = "https://api.spotify.com/v1/me/playlists?limit=50&offset=$offset"
        $result = Invoke-RestMethod -Uri $url -Headers $headers
        $allPlaylists += $result.items
        $offset += 50
    } while ($result.next -ne $null)
} catch {
    Write-Error "❌ Fehler beim Abrufen der Playlists: $($_.Exception.Message)"
    return
}

# === PLAYLISTS ALS CSV SPEICHERN ===
$csvData = foreach ($playlist in $allPlaylists) {
    [PSCustomObject]@{
        Name       = $playlist.name
        ID         = $playlist.id
        URL        = $playlist.external_urls.spotify
        Tracks_API = $playlist.tracks.href
    }
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$downloadsPath = [Environment]::GetFolderPath("UserProfile") + "\Downloads"
$csvPath = Join-Path $downloadsPath "spotify_playlists_export_$timestamp.csv"

try {
    $csvData | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
    Write-Host "`n📁 Playlists gespeichert unter: $csvPath" -ForegroundColor Green
} catch {
    Write-Error "❌ Fehler beim Schreiben der CSV-Datei – ist sie vielleicht noch geöffnet?"
}

# === LIKED SONGS EXPORTIEREN ===
Write-Host "`n🎧 Liked Songs werden geladen..."

$likedTracks = @()
$offset = 0

try {
    do {
        $url = "https://api.spotify.com/v1/me/tracks?limit=50&offset=$offset"
        $response = Invoke-RestMethod -Uri $url -Headers $headers
        $likedTracks += $response.items
        $offset += 50
    } while ($response.next -ne $null)
} catch {
    Write-Error "❌ Fehler beim Abrufen der Liked Songs: $($_.Exception.Message)"
    return
}

# === LIKED SONGS ALS CSV SPEICHERN ===
$likedCsv = foreach ($item in $likedTracks) {
    [PSCustomObject]@{
        TrackName = $item.track.name
        Artist    = $item.track.artists[0].name
        URI       = $item.track.uri
        ID        = $item.track.id
    }
}

$likedPath = Join-Path $downloadsPath "spotify_liked_songs_export_$timestamp.csv"

try {
    $likedCsv | Export-Csv -Path $likedPath -NoTypeInformation -Encoding UTF8
    Write-Host "`n📁 Liked Songs gespeichert unter: $likedPath" -ForegroundColor Green
} catch {
    Write-Error "❌ Fehler beim Schreiben der Liked Songs Datei – ist sie vielleicht offen?"
}
