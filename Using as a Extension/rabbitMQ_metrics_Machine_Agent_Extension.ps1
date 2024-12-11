# RabbitMQ Metrics Extension for AppDynamics Machine Agent
# Este script recupera métricas da API de Gerenciamento do RabbitMQ e as exibe no formato exigido pelo AppDynamics Machine Agent.
# As métricas são exibidas como "name=<metric name>,value=<value>,aggregator=<aggregator type>,time-rollup=<time-rollup strategy>,cluster-rollup=<cluster-rollup strategy>".

# Variáveis de Ambiente:
# Certifique-se de que as seguintes variáveis de ambiente estejam definidas:
# - RABBITMQ_USERNAME: Nome de usuário da API de Gerenciamento do RabbitMQ
# - RABBITMQ_PASSWORD: Senha da API de Gerenciamento do RabbitMQ
# - RABBITMQ_BASEURL: URL base para a API de Gerenciamento do RabbitMQ (por exemplo, http://localhost:15672)

# Recupera as credenciais da API de Gerenciamento do RabbitMQ das variáveis de ambiente
$Username = $Env:RABBITMQ_USERNAME
$Password = $Env:RABBITMQ_PASSWORD
$BaseUrl = $Env:RABBITMQ_BASEURL

# Valida se as variáveis de ambiente necessárias estão definidas
if (-not $Username -or -not $Password -or -not $BaseUrl) {
    Write-Output "Error: Missing required environment variables. Ensure RABBITMQ_USERNAME, RABBITMQ_PASSWORD, and RABBITMQ_BASEURL are set."
    exit 1
}

# Endpoint completo da API para as métricas de visão geral
$Url = "$BaseUrl/api/overview"

# Define todas as métricas disponíveis
$allAvailableMetrics = @(
    "Total Messages",
    "Messages Ready",
    "Deliver Get",
    "Total Consumers",
    "Connection Created Rate",
    "Connection Closed Rate"
)

# Define as métricas selecionadas (deixe vazio para incluir todas as métricas)
$selectedMetrics = @(
    "Deliver Get",
    "Total Consumers",
    "Total Messages",
    "Messages Ready"
)

# Se nenhuma métrica for selecionada, use todas as métricas disponíveis
if ($selectedMetrics.Count -eq 0) {
    $metricsToProcess = $allAvailableMetrics
    Write-Output "No specific metrics selected. Processing all available metrics."
} else {
    $metricsToProcess = $selectedMetrics
    Write-Output "Processing selected metrics: $($metricsToProcess -join ', ')"
}

try {
    # Converte a senha para SecureString e cria o objeto PSCredential
    $SecurePassword = ConvertTo-SecureString $Password -AsPlainText -Force
    $Credential = New-Object System.Management.Automation.PSCredential($Username, $SecurePassword)

    # Busca métricas da API de Gerenciamento do RabbitMQ
    $Response = Invoke-RestMethod -Uri $Url -Credential $Credential

    if ($Response -eq $null) {
        Write-Output "Error: No response received from RabbitMQ API."
        exit 1
    }

    # Exibe o JSON bruto da resposta para depuração
    $json = $Response | ConvertTo-Json -Depth 4
    Write-Output "Raw JSON Response:"
    Write-Output $json

    # Extrai métricas em um dicionário
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

    # Define os parâmetros de agregação e rollup
    $aggregator = "AVERAGE"
    $timeRollup = "AVERAGE"
    $clusterRollup = "INDIVIDUAL"

    # Saída das métricas no formato exigido
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
