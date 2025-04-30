# ---- Spotify OAuth Setup ----
$clientId = "ce60943b59c04bd6b5e017f01f570cca"
$clientSecret = "3b27d3cff4584f0db326a2ccc73ac894"
$redirectUri = "http://localhost:8888/callback"  # ⚠️ Dies muss in der Spotify Developer Console registriert sein!
$scope = "playlist-read-private playlist-read-collaborative"

# ---- Lokalen Listener starten ----
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:8888/callback/")
$listener.Start()
Write-Host "Lokaler Redirect-Listener läuft auf $redirectUri..."

# ---- Auth-URL aufbauen und Browser starten ----
$authUrl = "https://accounts.spotify.com/authorize?client_id=$clientId&response_type=code&redirect_uri=$redirectUri&scope=$scope"
Start-Process $authUrl

# ---- Auf Redirect warten und 'code' extrahieren ----
$context = $listener.GetContext()
$response = $context.Response
$code = [System.Web.HttpUtility]::ParseQueryString($context.Request.Url.Query).Get("code")

# HTML-Antwort im Browser anzeigen
$html = "<html><body><h2>✅ Login erfolgreich! Du kannst dieses Fenster jetzt schließen.</h2></body></html>"
$buffer = [System.Text.Encoding]::UTF8.GetBytes($html)
$response.ContentLength64 = $buffer.Length
$response.OutputStream.Write($buffer, 0, $buffer.Length)
$response.OutputStream.Close()
$listener.Stop()

Write-Host "Code empfangen: $code"

# ---- Access Token anfordern ----
$authBytes = [System.Text.Encoding]::ASCII.GetBytes("$clientId`:$clientSecret")
$authHeader = [Convert]::ToBase64String($authBytes)

$tokenResponse = Invoke-RestMethod -Method POST -Uri "https://accounts.spotify.com/api/token" `
    -Headers @{ Authorization = "Basic $authHeader" } `
    -Body @{
        grant_type    = "authorization_code"
        code          = $code
        redirect_uri  = $redirectUri
    }

$accessToken = $tokenResponse.access_token
Write-Host "Access Token erhalten!"

# ---- Playlists abrufen ----
$headers = @{ Authorization = "Bearer $accessToken" }
$allPlaylists = @()
$offset = 0

do {
    $url = "https://api.spotify.com/v1/me/playlists?limit=50&offset=$offset"
    $result = Invoke-RestMethod -Uri $url -Headers $headers
    $allPlaylists += $result.items
    $offset += 50
} while ($result.next -ne $null)

# ---- CSV-Daten aufbereiten ----
$csvData = foreach ($playlist in $allPlaylists) {
    [PSCustomObject]@{
        Name       = $playlist.name
        ID         = $playlist.id
        URL        = $playlist.external_urls.spotify
        Tracks_API = $playlist.tracks.href
    }
}

# ---- Datei speichern ----
$downloadsPath = [Environment]::GetFolderPath("UserProfile") + "\Downloads"
$csvPath = Join-Path $downloadsPath "spotify_playlists_export.csv"
$csvData | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
Write-Host "Playlists gespeichert unter: $csvPath" -ForegroundColor Green
