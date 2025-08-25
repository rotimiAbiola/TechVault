# AWS OIDC Setup for GitHub Actions

This document outlines the steps to configure OpenID Connect (OIDC) between GitHub Actions and AWS for secure authentication without storing long-term credentials.

## Prerequisites

- AWS CLI configured with administrative access
- Access to your GitHub repository settings
- AWS account with necessary permissions to create IAM roles and identity providers

## Step 1: Create OIDC Identity Provider in AWS

1. **Using AWS Console:**
   - Navigate to IAM → Identity Providers
   - Click "Add provider"
   - Select "OpenID Connect"
   - Provider URL: `https://token.actions.githubusercontent.com`
   - Audience: `sts.amazonaws.com`
   - Click "Add provider"

2. **Using AWS CLI:**
   ```bash
   aws iam create-open-id-connect-provider \
     --url https://token.actions.githubusercontent.com \
     --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1 \
     --audience-list sts.amazonaws.com
   ```

## Step 2: Create IAM Role for GitHub Actions

Create an IAM role that GitHub Actions can assume:

```bash
# Create trust policy file
cat > github-actions-trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::YOUR_ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:YOUR_GITHUB_USERNAME/TechVault:*"
        }
      }
    }
  ]
}
EOF

# Create the role
aws iam create-role \
  --role-name TechVault-GitHub-Actions-Role \
  --assume-role-policy-document file://github-actions-trust-policy.json

# Get the role ARN (save this for GitHub secrets)
aws iam get-role --role-name TechVault-GitHub-Actions-Role --query 'Role.Arn' --output text
```

## Step 3: Attach Permissions to the Role

Create and attach a policy with necessary permissions for Terraform:

```bash
# Create permissions policy file
cat > terraform-permissions-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:*",
        "ecs:*",
        "elasticloadbalancing:*",
        "rds:*",
        "elasticache:*",
        "es:*",
        "s3:*",
        "logs:*",
        "ssm:*",
        "cloudwatch:*",
        "sns:*",
        "application-autoscaling:*",
        "route53:*",
        "acm:*"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "iam:GetRole",
        "iam:GetRolePolicy",
        "iam:GetInstanceProfile",
        "iam:ListAttachedRolePolicies",
        "iam:ListRolePolicies",
        "iam:ListInstanceProfilesForRole",
        "iam:CreateRole",
        "iam:DeleteRole",
        "iam:UpdateRole",
        "iam:TagRole",
        "iam:UntagRole",
        "iam:CreateInstanceProfile",
        "iam:DeleteInstanceProfile",
        "iam:AddRoleToInstanceProfile",
        "iam:RemoveRoleFromInstanceProfile",
        "iam:AttachRolePolicy",
        "iam:DetachRolePolicy",
        "iam:PutRolePolicy",
        "iam:DeleteRolePolicy"
      ],
      "Resource": [
        "arn:aws:iam::*:role/techvault-*",
        "arn:aws:iam::*:instance-profile/techvault-*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "iam:PassRole"
      ],
      "Resource": [
        "arn:aws:iam::*:role/techvault-*"
      ],
      "Condition": {
        "StringEquals": {
          "iam:PassedToService": [
            "ecs-tasks.amazonaws.com",
            "ec2.amazonaws.com",
            "rds.amazonaws.com"
          ]
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "iam:GetPolicy",
        "iam:GetPolicyVersion",
        "iam:ListPolicyVersions"
      ],
      "Resource": [
        "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy",
        "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
      ]
    }
  ]
}
EOF

# Create the policy
aws iam create-policy \
  --policy-name TechVault-Terraform-Policy \
  --policy-document file://terraform-permissions-policy.json

# Attach policy to role
aws iam attach-role-policy \
  --role-name TechVault-GitHub-Actions-Role \
  --policy-arn arn:aws:iam::YOUR_ACCOUNT_ID:policy/TechVault-Terraform-Policy
```

## Step 4: Configure GitHub Repository Secrets

1. Go to your GitHub repository
2. Navigate to Settings → Secrets and variables → Actions
3. Add the following repository secret:
   - **Name:** `AWS_ROLE_ARN`
   - **Value:** The role ARN from Step 2 (format: `arn:aws:iam::YOUR_ACCOUNT_ID:role/TechVault-GitHub-Actions-Role`)

## Step 5: Verify Configuration

Test the OIDC configuration by running a simple GitHub Actions workflow that assumes the role:

```yaml
# Test workflow
name: Test OIDC
on: workflow_dispatch

permissions:
  id-token: write
  contents: read

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          role-session-name: test-session
          aws-region: us-west-2
      
      - name: Test AWS access
        run: aws sts get-caller-identity
```

## Security Considerations

1. **Principle of Least Privilege:** The policy above grants only the minimum permissions required for TechVault infrastructure
2. **Resource Restrictions:** IAM permissions are restricted to resources with `techvault-*` naming pattern
3. **PassRole Conditions:** `iam:PassRole` is restricted to specific AWS services that actually need it
4. **Condition Constraints:** The trust policy includes conditions to ensure only your specific repository can assume the role
5. **Branch Protection:** Consider adding branch-specific conditions in the trust policy
6. **Regular Auditing:** Regularly review and audit the permissions granted to the role

### IAM Policy Breakdown

The policy includes three main statements:

1. **General AWS Services:** Full access to AWS services needed for infrastructure (EC2, ECS, RDS, etc.)
2. **IAM Role Management:** Limited IAM permissions for creating and managing TechVault-specific roles
3. **PassRole with Conditions:** Restricted PassRole permissions only for ECS, EC2, and RDS services

### Alternative Minimal Policy

For environments requiring even stricter controls, you can use this more restrictive policy:

```bash
# Create minimal permissions policy file
cat > terraform-minimal-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:Describe*",
        "ec2:Create*",
        "ec2:Delete*",
        "ec2:Modify*",
        "ec2:*SecurityGroup*",
        "ec2:*Subnet*",
        "ec2:*Vpc*",
        "ec2:*InternetGateway*",
        "ec2:*RouteTable*",
        "ec2:*Route",
        "ec2:*Instance*",
        "ecs:*",
        "elasticloadbalancing:*",
        "rds:*",
        "elasticache:*",
        "es:*",
        "logs:*",
        "ssm:*Parameter*",
        "cloudwatch:*",
        "sns:*"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:*"
      ],
      "Resource": [
        "arn:aws:s3:::techvault-*",
        "arn:aws:s3:::techvault-*/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "iam:GetRole",
        "iam:CreateRole",
        "iam:DeleteRole",
        "iam:AttachRolePolicy",
        "iam:DetachRolePolicy",
        "iam:PutRolePolicy",
        "iam:DeleteRolePolicy",
        "iam:TagRole"
      ],
      "Resource": [
        "arn:aws:iam::*:role/techvault-*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "iam:PassRole"
      ],
      "Resource": [
        "arn:aws:iam::*:role/techvault-*"
      ],
      "Condition": {
        "StringEquals": {
          "iam:PassedToService": [
            "ecs-tasks.amazonaws.com",
            "rds.amazonaws.com"
          ]
        }
      }
    }
  ]
}
EOF
```

## Troubleshooting

### Common Issues:

1. **Invalid Identity Token:** Ensure the workflow has `id-token: write` permission
2. **Trust Policy Issues:** Verify the repository path in the trust policy condition
3. **Thumbprint Mismatch:** Ensure the correct thumbprint is used for the OIDC provider
4. **Permission Denied:** Check if the IAM role has sufficient permissions for the specific resources being created
5. **PassRole Error:** Verify that the role being passed matches the allowed resource pattern and service condition

### Debug Commands:

```bash
# Check if OIDC provider exists
aws iam list-open-id-connect-providers

# Verify role trust policy
aws iam get-role --role-name TechVault-GitHub-Actions-Role

# Check attached policies
aws iam list-attached-role-policies --role-name TechVault-GitHub-Actions-Role

# Simulate policy permissions (replace with actual resources)
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::YOUR_ACCOUNT_ID:role/TechVault-GitHub-Actions-Role \
  --action-names iam:PassRole \
  --resource-arns arn:aws:iam::YOUR_ACCOUNT_ID:role/techvault-development-ecs-task-execution-role
```

### Policy Validation:

Test your IAM policy with AWS Policy Simulator:
1. Go to AWS Console → IAM → Policy Simulator
2. Select your TechVault GitHub Actions role
3. Test specific actions like `iam:PassRole` with your resource ARNs
4. Verify conditions are working correctly

## Replace Placeholders

Before running the commands, replace the following placeholders:

- `YOUR_ACCOUNT_ID`: Your AWS account ID
- `YOUR_GITHUB_USERNAME`: Your GitHub username (e.g., `rotimiAbiola`)

## Benefits of OIDC vs Access Keys

1. **No Long-term Credentials:** Tokens are short-lived and automatically rotated
2. **Enhanced Security:** No need to store AWS access keys in GitHub secrets
3. **Granular Control:** Fine-grained control over which repositories and branches can access AWS
4. **Audit Trail:** Better auditing capabilities with CloudTrail
5. **Compliance:** Meets security compliance requirements for credential management

## Monitoring and Compliance

### CloudTrail Monitoring
Enable CloudTrail to monitor all API calls made by the GitHub Actions role:

```bash
# Example CloudWatch alarm for monitoring role usage
aws cloudwatch put-metric-alarm \
  --alarm-name "TechVault-GitHub-Actions-Role-Usage" \
  --alarm-description "Monitor GitHub Actions role usage" \
  --metric-name "ErrorCount" \
  --namespace "AWS/CloudTrail" \
  --statistic "Sum" \
  --period 300 \
  --threshold 5 \
  --comparison-operator "GreaterThanThreshold" \
  --dimensions Name=User,Value=TechVault-GitHub-Actions-Role \
  --evaluation-periods 1
```

### Security Best Practices
1. **Regular Policy Reviews:** Review permissions quarterly
2. **Least Privilege Updates:** Remove unused permissions over time
3. **Resource Tagging:** Tag all resources for better tracking
4. **Cross-Account Access:** Use separate roles for different environments
5. **Condition Testing:** Regularly test condition constraints

### Compliance Documentation
Document the following for compliance audits:
- Role purpose and justification for each permission
- List of GitHub repositories with access
- Regular access review process
- Incident response procedures for compromised tokens
