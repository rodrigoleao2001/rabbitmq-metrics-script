# This script retrieves metrics from the RabbitMQ Management API and sends them to the AppDynamics Machine Agent HTTP Listener.
# It queries the RabbitMQ API to get queue and message statistics, formats these metrics, and sends them to AppDynamics.
#
# To activate the AppDynamics Machine Agent with the HTTP Listener on port 8293, use the following command:
# java -jar machine-agent.jar -Dmetric.http.listener=true -Dmetric.http.listener.port=8293
#
# Environment Variables:
# Ensure the following environment variables are set before running the script:
# - RABBITMQ_USERNAME: RabbitMQ Management API username
# - RABBITMQ_PASSWORD: RabbitMQ Management API password
# - RABBITMQ_BASEURL: Base URL for the RabbitMQ Management API (e.g., http://localhost:15672)

# Main Metrics Available for Extraction and Selection:
# - Total Messages: Total number of messages across all queues.
# - Messages Ready: Number of messages ready for delivery.
# - Deliver Get: Number of messages delivered to consumers.
# - Total Consumers: Total number of consumers.
# - Connection Created Rate: Rate of new connections created.
# - Connection Closed Rate: Rate of connections closed.

# Retrieve RabbitMQ Management API credentials from environment variables
$Username = $Env:RABBITMQ_USERNAME  # RabbitMQ API username
$Password = $Env:RABBITMQ_PASSWORD  # RabbitMQ API password
$BaseUrl = $Env:RABBITMQ_BASEURL    # Base URL for RabbitMQ API

# Validate that required environment variables are set
if (-not $Username -or -not $Password -or -not $BaseUrl) {
    Write-Output "Error: Missing required environment variables. Ensure RABBITMQ_USERNAME, RABBITMQ_PASSWORD, and RABBITMQ_BASEURL are set."
    exit 1
}

# Full API endpoint for the overview metrics
$Url = "$BaseUrl/api/overview"

# List of selected metrics to monitor
$selectedMetrics = @()  # Leave empty to process all metrics

# Define default metrics if selectedMetrics is empty
$allAvailableMetrics = @(
    "Total Messages",
    "Messages Ready",
    "Deliver Get",
    "Total Consumers",
    "Connection Created Rate",
    "Connection Closed Rate"
)

# Function to send metrics to AppDynamics using the Machine Agent HTTP Listener
function PostMetricToAppD {
    param(
        [string]$metricPath,    # Path where the metric will appear in AppDynamics
        [string]$metricName,    # Name of the metric
        [double]$metricValue    # Value of the metric
    )

    $metricFullName = "$metricPath|$metricName"
    $metricData = @(
        @{
            "metricName"     = $metricFullName
            "aggregatorType" = "OBSERVATION"
            "value"          = $metricValue
        }
    )

    $json = '[ ' + ($metricData | ConvertTo-Json) + ' ]'
    Write-Output "Sending metric '$metricFullName' with value $metricValue to the AppDynamics Machine Agent HTTP Listener..."

    try {
        $response = Invoke-WebRequest -Uri 'http://localhost:8293/api/v1/metrics' -Method POST -Body $json -ContentType 'application/json'
        if ($response.StatusCode -eq 200 -or $response.StatusCode -eq 204) {
            Write-Output "Metric '$metricFullName' sent successfully."
        } else {
            Write-Output "Failed to send metric '$metricFullName'. Status Code: $($response.StatusCode)"
        }
    } catch {
        Write-Output "Error sending metric '$metricFullName': $($_.Exception.Message)"
    }
}

# Main logic of the script
try {
    Write-Output "Converting password to SecureString..."
    $SecurePassword = ConvertTo-SecureString $Password -AsPlainText -Force
    Write-Output "Creating PSCredential object..."
    $Credential = New-Object System.Management.Automation.PSCredential($Username, $SecurePassword)

    Write-Output "Fetching metrics from RabbitMQ Management API at $Url..."
    $Response = Invoke-RestMethod -Uri $Url -Credential $Credential

    if ($Response -eq $null) {
        Write-Output "Error: No response received from RabbitMQ API."
        exit 1
    }

    Write-Output "Successfully received response from RabbitMQ API."

    # Extract metrics into a dictionary
    $allMetrics = @{
        "Total Messages"          = if ($Response.queue_totals.messages -ne $null) { [int]$Response.queue_totals.messages } else { 0 }
        "Messages Ready"          = if ($Response.queue_totals.messages_ready -ne $null) { [int]$Response.queue_totals.messages_ready } else { 0 }
        "Deliver Get"             = if ($Response.message_stats -ne $null -and $Response.message_stats.deliver_get -ne $null) { [int]$Response.message_stats.deliver_get } else { 0 }
        "Total Consumers"         = if ($Response.object_totals.consumers -ne $null) { [int]$Response.object_totals.consumers } else { 0 }
        "Connection Created Rate" = if ($Response.churn_rates.connection_created_details.rate -ne $null) { [double]$Response.churn_rates.connection_created_details.rate } else { 0 }
        "Connection Closed Rate"  = if ($Response.churn_rates.connection_closed_details.rate -ne $null) { [double]$Response.churn_rates.connection_closed_details.rate } else { 0 }
    }

    # Determine which metrics to process
    if ($selectedMetrics.Count -eq 0) {
        # If metrics list is empty, process all available metrics
        $metricsToProcess = $allAvailableMetrics
        Write-Output "No specific metrics selected. Processing all available metrics."
    }
    else {
        # Use specified metrics
        $metricsToProcess = $selectedMetrics
        Write-Output "Processing selected metrics: $($metricsToProcess -join ', ')"
    }

    Write-Output "Processing metrics..."
    foreach ($metric in $metricsToProcess) {
        if ($allMetrics.ContainsKey($metric)) {
            $metricValue = $allMetrics[$metric]
            if ($metricValue -eq $null) {
                Write-Output "Metric '$metric' is empty. Sending as 0."
                $metricValue = 0
            }
            Write-Output "Sending metric '$metric' with value $metricValue..."
            PostMetricToAppD -metricPath "Custom Metrics|RabbitMQ" -metricName $metric -metricValue $metricValue
        } else {
            Write-Output "Metric '$metric' is not available in the response. Skipping."
        }
    }

    Write-Output "All selected metrics have been processed."

} catch {
    Write-Output "An error occurred: $($_.Exception.Message)"
    exit 1
}

Write-Output "Script execution completed."
