# RabbitMQ Metrics Extension for AppDynamics Machine Agent
# This script retrieves metrics from the RabbitMQ Management API and outputs them in the format required by the AppDynamics Machine Agent.
# Metrics are displayed as "name=<metric name>,value=<value>,aggregator=<aggregator type>,time-rollup=<time-rollup strategy>,cluster-rollup=<cluster-rollup strategy>".

# Environment Variables:
# Ensure the following environment variables are set:
# - RABBITMQ_USERNAME: RabbitMQ Management API username
# - RABBITMQ_PASSWORD: RabbitMQ Management API password
# - RABBITMQ_BASEURL: Base URL for the RabbitMQ Management API (e.g., http://localhost:15672)

# Retrieve RabbitMQ Management API credentials from environment variables
$Username = $Env:RABBITMQ_USERNAME
$Password = $Env:RABBITMQ_PASSWORD
$BaseUrl = $Env:RABBITMQ_BASEURL

# Validate if required environment variables are set
if (-not $Username -or -not $Password -or -not $BaseUrl) {
    Write-Output "Error: Missing required environment variables. Ensure RABBITMQ_USERNAME, RABBITMQ_PASSWORD, and RABBITMQ_BASEURL are set."
    exit 1
}

# Full API endpoint for overview metrics
$Url = "$BaseUrl/api/overview"

# Define all available metrics
$allAvailableMetrics = @(
    "Total Messages",
    "Messages Ready",
    "Deliver Get",
    "Total Consumers",
    "Connection Created Rate",
    "Connection Closed Rate"
)

# Define selected metrics (leave empty to include all available metrics)
$selectedMetrics = @(
    "Deliver Get",
    "Total Consumers",
    "Total Messages",
    "Messages Ready"
)

# Use all available metrics if none are selected
if ($selectedMetrics.Count -eq 0) {
    $metricsToProcess = $allAvailableMetrics
    Write-Output "No specific metrics selected. Processing all available metrics."
} else {
    $metricsToProcess = $selectedMetrics
    Write-Output "Processing selected metrics: $($metricsToProcess -join ', ')"
}

try {
    # Convert password to SecureString and create PSCredential object
    $SecurePassword = ConvertTo-SecureString $Password -AsPlainText -Force
    $Credential = New-Object System.Management.Automation.PSCredential($Username, $SecurePassword)

    # Fetch metrics from RabbitMQ Management API
    $Response = Invoke-RestMethod -Uri $Url -Credential $Credential

    if ($Response -eq $null) {
        Write-Output "Error: No response received from RabbitMQ API."
        exit 1
    }

    # Output raw JSON response for debugging
    $json = $Response | ConvertTo-Json -Depth 4
    Write-Output "Raw JSON Response:"
    Write-Output $json

    # Extract metrics into a dictionary
    $allMetrics = @(
        @{
            Metric = "Total Messages"
            Value = if ($Response.queue_totals.messages -ne $null) { [int]$Response.queue_totals.messages } else { 0 }
        },
        @{
            Metric = "Messages Ready"
            Value = if ($Response.queue_totals.messages_ready -ne $null) { [int]$Response.queue_totals.messages_ready } else { 0 }
        },
        @{
            Metric = "Deliver Get"
            Value = if ($Response.message_stats -ne $null -and $Response.message_stats.deliver_get -ne $null) { [int]$Response.message_stats.deliver_get } else { 0 }
        },
        @{
            Metric = "Total Consumers"
            Value = if ($Response.object_totals.consumers -ne $null) { [int]$Response.object_totals.consumers } else { 0 }
        },
        @{
            Metric = "Connection Created Rate"
            Value = if ($Response.churn_rates.connection_created_details.rate -ne $null) { [double]$Response.churn_rates.connection_created_details.rate } else { 0 }
        },
        @{
            Metric = "Connection Closed Rate"
            Value = if ($Response.churn_rates.connection_closed_details.rate -ne $null) { [double]$Response.churn_rates.connection_closed_details.rate } else { 0 }
        }
    )

    # Define aggregation and roll-up parameters
    $aggregator = "AVERAGE"
    $timeRollup = "AVERAGE"
    $clusterRollup = "INDIVIDUAL"

    # Output metrics in the required format
    foreach ($metric in $metricsToProcess) {
        $metricObject = $allMetrics | Where-Object { $_.Metric -eq $metric }
        if ($metricObject -ne $null) {
            $metricPath = "Custom Metrics|RabbitMQ|$($metricObject.Metric)"
            $metricValue = $metricObject.Value
            Write-Output "name=$metricPath,value=$metricValue,aggregator=$aggregator,time-rollup=$timeRollup,cluster-rollup=$clusterRollup"
        } else {
            Write-Output "Metric '$metric' is not available in the response. Skipping."
        }
    }

    Write-Output "Metrics successfully processed."
    exit 0

} catch {
    Write-Output "An error occurred: $($_.Exception.Message)"
    exit 1
}
