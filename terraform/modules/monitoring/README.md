# TechVault CloudWatch Monitoring & Logging

This document describes the comprehensive CloudWatch monitoring and logging implementation for the TechVault platform.

## 🎯 Overview

The monitoring setup provides:
- **Application-level logging** for all microservices
- **Infrastructure monitoring** with automated alerts
- **Custom CloudWatch dashboard** for operational visibility
- **SNS alerting** for critical issues

## 📊 Monitoring Components

### 1. CloudWatch Log Groups
- `/aws/ecs/techvault-{env}-frontend` - React frontend logs
- `/aws/ecs/techvault-{env}-gateway` - Node.js API gateway logs
- `/aws/ecs/techvault-{env}-product` - Go product service logs
- `/aws/ecs/techvault-{env}-payment` - Java payment service logs
- `/aws/ecs/techvault-{env}-auth` - Python auth service logs
- `/aws/ecs/techvault-{env}-cluster` - ECS cluster logs

### 2. CloudWatch Alarms

#### ECS Cluster Monitoring
- **CPU Utilization** > 80% (2 evaluation periods)
- **Memory Utilization** > 80% (2 evaluation periods)

#### Application Load Balancer Monitoring
- **Response Time** > 1 second (2 evaluation periods)
- **Unhealthy Hosts** > 0 (2 evaluation periods)

#### RDS Database Monitoring
- **CPU Utilization** > 80% (2 evaluation periods)
- **Connection Count** > 80 (2 evaluation periods)
- **Free Storage Space** < 2GB (2 evaluation periods)

#### Redis Cache Monitoring
- **CPU Utilization** > 80% (2 evaluation periods)
- **Memory Utilization** > 80% (2 evaluation periods)

### 3. CloudWatch Dashboard

The dashboard includes:
- **ECS Cluster Metrics** - CPU and Memory utilization
- **Load Balancer Metrics** - Request count, response time, HTTP status codes
- **Database Metrics** - CPU, connections, read/write latency
- **Cache Metrics** - CPU, memory usage, connections
- **Recent Application Logs** - Last 100 log entries from all services

## 🔔 Alert Configuration

### SNS Topic
- Topic: `techvault-{environment}-alerts`
- Subscription: Email notifications (configure in tfvars)

### Setting up Email Alerts
1. Add your email to the environment configuration:
   ```hcl
   # In terraform/environments/dev.tfvars or prod.tfvars
   alert_email = "your-email@example.com"
   ```

2. After deployment, confirm the SNS subscription in your email

## 🚀 Deployment

### Deploy with Terraform
```bash
cd terraform

# Initialize (first time only)
terraform init

# Plan the deployment
terraform plan -var-file="environments/dev.tfvars"

# Apply the changes
terraform apply -var-file="environments/dev.tfvars"
```

## 📈 Accessing Monitoring

### CloudWatch Dashboard
After deployment, access the dashboard via:
- AWS Console → CloudWatch → Dashboards → `techvault-{environment}-dashboard`
- Or use the dashboard URL from Terraform output

### CloudWatch Logs
- AWS Console → CloudWatch → Log groups
- Filter by `/aws/ecs/techvault-{environment}-*`

### CloudWatch Alarms
- AWS Console → CloudWatch → Alarms
- All alarms are prefixed with `techvault-{environment}-*`

## 🎛️ ECS Task Logging

All ECS tasks are configured with `awslogs` driver:
```json
{
  "logConfiguration": {
    "logDriver": "awslogs",
    "options": {
      "awslogs-group": "/aws/ecs/techvault-{env}-{service}",
      "awslogs-region": "us-west-2",
      "awslogs-stream-prefix": "ecs"
    }
  }
}
```

## 🔧 Configuration

### Log Retention
- Default: 30 days
- Configurable via `log_retention_days` variable
- Set in environment-specific tfvars files

### Alert Thresholds
Current thresholds are set for typical microservices workloads:
- CPU/Memory: 80%
- Response time: 1 second
- Storage: 2GB minimum

To customize, modify the monitoring module alarm configurations.

## 📊 Metrics Available

### Container Insights (ECS)
- CPU utilization per service
- Memory utilization per service
- Network I/O metrics
- Storage metrics

### Enhanced RDS Monitoring
- 60-second granularity
- OS-level metrics
- Performance Insights enabled

### Custom Application Metrics
Services can publish custom metrics using AWS SDK:
```javascript
// Example for Node.js services
const cloudwatch = new AWS.CloudWatch();
await cloudwatch.putMetricData({
  Namespace: 'TechVault/Application',
  MetricData: [{
    MetricName: 'OrdersProcessed',
    Value: 1,
    Unit: 'Count'
  }]
}).promise();
```

## 🛠️ Troubleshooting

### Common Issues

1. **No log data appearing**
   - Check ECS task execution role has CloudWatch Logs permissions
   - Verify log group names match task definitions

2. **Alarms not triggering**
   - Confirm SNS topic subscription is confirmed
   - Check alarm evaluation periods and thresholds

3. **Dashboard not showing data**
   - Verify resource names match dashboard configuration
   - Check CloudWatch permissions for viewing role

### Useful CloudWatch Insights Queries

```sql
-- Find errors in application logs
SOURCE '/aws/ecs/techvault-{env}-gateway'
| fields @timestamp, @message
| filter @message like /ERROR/
| sort @timestamp desc
| limit 100

-- Monitor response times
SOURCE '/aws/ecs/techvault-{env}-gateway'
| fields @timestamp, @message
| filter @message like /response_time/
| stats avg(response_time) by bin(5m)
```

## 💰 Cost Optimization

- Log retention set to 30 days (configurable)
- Enhanced monitoring only enabled for production RDS
- Container Insights automatically optimized for cost
- Alarm evaluation periods minimize false positives

---

**Dashboard URL**: Available in Terraform outputs after deployment
**Documentation**: This README and Terraform module documentation
**Support**: Check CloudWatch console for real-time monitoring status
