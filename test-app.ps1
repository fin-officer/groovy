# PowerShell script to test the Email-LLM Integration application

# Colors for output
$GREEN = "`e[0;32m"
$BLUE = "`e[0;34m"
$YELLOW = "`e[1;33m"
$RED = "`e[0;31m"
$NC = "`e[0m" # No Color

# Function to display test results
function Show-TestResult {
    param (
        [string]$testName,
        [bool]$success,
        [string]$message = ""
    )
    
    if ($success) {
        Write-Host "${GREEN}[PASS]${NC} $testName"
    } else {
        Write-Host "${RED}[FAIL]${NC} $testName $message"
    }
}

# Function to make HTTP requests
function Invoke-ApiRequest {
    param (
        [string]$method,
        [string]$endpoint,
        [object]$body = $null,
        [string]$contentType = "application/json"
    )
    
    # Use the base URL provided or default to the standard port
    if (-not [string]::IsNullOrEmpty($baseUrl)) {
        # Use the provided base URL
    } else {
        $baseUrl = "http://localhost:8080"  # Default API port mapped to container port
    }
    $url = "$baseUrl$endpoint"
    
    try {
        $headers = @{
            "Content-Type" = $contentType
            "Accept" = "application/json"
        }
        
        $params = @{
            Method = $method
            Uri = $url
            Headers = $headers
            UseBasicParsing = $true
        }
        
        if ($null -ne $body) {
            if ($body -is [string]) {
                $params.Body = $body
            } else {
                $params.Body = $body | ConvertTo-Json -Depth 10
            }
        }
        
        $response = Invoke-WebRequest @params
        
        if ($response.StatusCode -ge 200 -and $response.StatusCode -lt 300) {
            return @{
                Success = $true
                StatusCode = $response.StatusCode
                Content = $response.Content
                Response = $response
            }
        } else {
            return @{
                Success = $false
                StatusCode = $response.StatusCode
                Content = $response.Content
                Response = $response
                Error = "Request failed with status code $($response.StatusCode)"
            }
        }
    } catch {
        return @{
            Success = $false
            Error = $_.Exception.Message
            Exception = $_
        }
    }
}

# Function to send a test email
function Send-TestEmail {
    param (
        [string]$to = "test@example.com",
        [string]$subject = "Test Email",
        [string]$body = "This is a test email."
    )
    
    try {
        $smtpServer = "localhost"
        $smtpPort = 1026  # MailHog SMTP port
        
        $smtpClient = New-Object System.Net.Mail.SmtpClient($smtpServer, $smtpPort)
        $message = New-Object System.Net.Mail.MailMessage
        $message.From = "sender@example.com"
        $message.To.Add($to)
        $message.Subject = $subject
        $message.Body = $body
        $message.IsBodyHtml = $false
        
        $smtpClient.Send($message)
        
        return @{
            Success = $true
            Message = "Email sent successfully"
        }
    } catch {
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

# Function to check if Docker containers are running
function Test-ContainersRunning {
    $requiredContainers = @("ollama", "mailserver", "camel-groovy-email-llm", "adminer")
    $allRunning = $true
    $notRunning = @()
    
    foreach ($container in $requiredContainers) {
        $containerStatus = docker ps --filter "name=$container" --format "{{.Status}}"
        
        if (-not $containerStatus) {
            $allRunning = $false
            $notRunning += $container
        }
    }
    
    if ($allRunning) {
        return @{
            Success = $true
            Message = "All required containers are running"
        }
    } else {
        return @{
            Success = $false
            Error = "The following containers are not running: $($notRunning -join ', ')"
        }
    }
}

# Main test function
function Run-Tests {
    $testResults = @()
    $totalTests = 0
    $passedTests = 0
    
    Write-Host "${BLUE}=== Starting Email-LLM Integration Tests ===${NC}"
    Write-Host "Date: $(Get-Date)"
    Write-Host ""
    
    # Test 1: Check if containers are running
    $totalTests++
    $containerCheck = Test-ContainersRunning
    Show-TestResult -testName "Container Status Check" -success $containerCheck.Success -message $containerCheck.Error
    if ($containerCheck.Success) { $passedTests++ }
    
    # Check container logs for errors
    Write-Host "${BLUE}[INFO]${NC} Checking container logs for errors..."
    $camelLogs = docker logs camel-groovy-email-llm 2>&1
    if ($camelLogs -match "Error" -or $camelLogs -match "Exception") {
        Write-Host "${YELLOW}[WARNING]${NC} Found errors in camel-groovy-email-llm logs:"
        $errorLines = $camelLogs -split "`n" | Where-Object { $_ -match "Error" -or $_ -match "Exception" }
        foreach ($line in $errorLines) {
            Write-Host "  $line"
        }
        Write-Host ""
    }
    
    # Test 2: Health check API
    $totalTests++
    $healthCheck = Invoke-ApiRequest -method "GET" -endpoint "/api/health"
    Show-TestResult -testName "API Health Check" -success $healthCheck.Success -message $healthCheck.Error
    if ($healthCheck.Success) { $passedTests++ }
    
    # Test 3: API Documentation endpoint
    $totalTests++
    $apiDocCheck = Invoke-ApiRequest -method "GET" -endpoint "/api/api-doc"
    Show-TestResult -testName "API Documentation Check" -success $apiDocCheck.Success -message $apiDocCheck.Error
    if ($apiDocCheck.Success) { $passedTests++ }
    
    # Test 4: LLM Direct Analysis API
    $totalTests++
    $llmAnalysisBody = @{
        text = "Please schedule a meeting for tomorrow at 2 PM to discuss the project status."
        context = "Project planning"
        model = "mistral"
    }
    
    $llmAnalysis = Invoke-ApiRequest -method "POST" -endpoint "/api/llm/direct-analyze" -body $llmAnalysisBody
    Show-TestResult -testName "LLM Analysis API" -success $llmAnalysis.Success -message $llmAnalysis.Error
    if ($llmAnalysis.Success) { $passedTests++ }
    
    # Test 5: Send test email
    $totalTests++
    $emailTest = Send-TestEmail -subject "Test Email from PowerShell" -body "This is an automated test email sent from the PowerShell test script."
    Show-TestResult -testName "Send Test Email" -success $emailTest.Success -message $emailTest.Error
    if ($emailTest.Success) { $passedTests++ }
    
    # Test 6: Check MailHog API for received emails
    $totalTests++
    Start-Sleep -Seconds 2  # Wait for email processing
    $mailhogCheck = Invoke-ApiRequest -method "GET" -endpoint "/api/v2/messages" -baseUrl "http://localhost:8026"
    $mailhogSuccess = $mailhogCheck.Success -and ($mailhogCheck.Content -match "Test Email from PowerShell")
    Show-TestResult -testName "MailHog Email Check" -success $mailhogSuccess -message "Failed to find test email in MailHog"
    if ($mailhogSuccess) { $passedTests++ }
    
    # Summary
    Write-Host ""
    Write-Host "${BLUE}=== Test Summary ===${NC}"
    Write-Host "Total Tests: $totalTests"
    Write-Host "Passed: ${GREEN}$passedTests${NC}"
    Write-Host "Failed: ${RED}$($totalTests - $passedTests)${NC}"
    
    if ($passedTests -eq $totalTests) {
        Write-Host "${GREEN}All tests passed!${NC}"
    } else {
        Write-Host "${YELLOW}Some tests failed. Check the logs for details.${NC}"
    }
}

# Run the tests
Run-Tests