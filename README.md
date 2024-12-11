# RabbitMQ Metrics Extension for AppDynamics Machine Agent

This document explains how to configure and execute the RabbitMQ metrics extension for AppDynamics using two methods:

1. **Machine Agent Extension** (configured via `monitor.xml`).
2. **HTTP Listener** (sends metrics directly to the AppDynamics HTTP listener).

---

## Prerequisites

1. Ensure the RabbitMQ Management Plugin is enabled.
2. Set up credentials for the RabbitMQ Management API.
3. Install and configure the AppDynamics Machine Agent.
4. Verify that PowerShell is available for execution on the machine.

---

## 1. Machine Agent Extension

### Steps to Configure

1. Set environment variables:
   - `RABBITMQ_USERNAME`: RabbitMQ API username.
   - `RABBITMQ_PASSWORD`: RabbitMQ API password.
   - `RABBITMQ_BASEURL`: RabbitMQ API base URL.

2. Place the PowerShell script and a `.bat` file in a subdirectory under the `monitors` directory in the Machine Agent installation path. The `.bat` file should execute the PowerShell script.

3. Create and place the `monitor.xml` file in the same subdirectory. Configure it to execute the `.bat` file periodically.

4. Restart the Machine Agent to apply the changes.

5. Verify the metrics in the AppDynamics Metric Browser under the `Custom Metrics|RabbitMQ` path.

---

## 2. HTTP Listener

### Steps to Configure

1. Enable the HTTP listener in the Machine Agent configuration file by setting the appropriate port and enabling the feature.

2. Set environment variables:
   - `RABBITMQ_USERNAME`: RabbitMQ API username.
   - `RABBITMQ_PASSWORD`: RabbitMQ API password.
   - `RABBITMQ_BASEURL`: RabbitMQ API base URL.

3. Execute the PowerShell script directly to send metrics to the HTTP listener.

4. Verify the metrics in the AppDynamics Metric Browser under the `Custom Metrics|RabbitMQ` path.