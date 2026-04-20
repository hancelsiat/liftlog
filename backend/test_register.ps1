$body = @"
{
  \"username\": \"testuser123\",
  \"email\": \"testuser123@example.com\",
  \"password\": \"test123\",
  \"role\": \"member\"
}
"@

Invoke-WebRequest -Uri "http://localhost:10000/api/auth/register" -Method POST -ContentType "application/json" -Body $body