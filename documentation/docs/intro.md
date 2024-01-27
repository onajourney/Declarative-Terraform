---
sidebar_position: 1
---

# Tutorial Intro

Let's discover **FS Terraform in less than 5 minutes**.

## Our file structure

```
infrastructure/
├─ helpers/
├─ dev/
│  └─ maint.tf
├─ aws/
│  ├─ modules/
│  │  ├─ dynamodb.tf
│  │  └─ lambda.tf
|  └─ resources/
│     ├─ dynamodb/
│     │  ├─ Table1.json
│     │  └─ Table2.json
│     └─ lambda/
│        ├─ function1/
│        |  ├─ config.json
│        |  ├─ index.js
│        |  └─ test.js
│        └─ function2/
│           └─ index.js
├─ aws.tf
├─ main.tf
└─ variables.tf
```

Let's break down the usage of each:
- **helpers** provide scripts for lambda deployment (npm installs, etc).
- **dev** facilitates local development with local stack.
- **aws** contains aws infrastructure.
- **aws.tf** contains FS code to boostrap `/aws` and aws provider.
- **main.tf** contains our terraform configuration.
- **variables.tf** contains our deployment variables (region, environment).

## Testing locally

- Install Docker
- Install LocalStack desktop and create a container
- Run `npm run tf:init`
- Run `npm run tf:apply`

## Local testing in a live environment

## Deploying to a live environment

- Create `AWS_ACCESS_KEY` and `AWS_SECRET_KEY` secrets under the repository
- Create a `AWS_REGION` variable under the repository 
- Create a `.github\workflows\live.yml` workflow file

```yml
name: Live Test Environment

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    env:
      AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY }}
      AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_KEY }}
      AWS_REGION: ${{ vars.AWS_REGION }}
      TF_VAR_aws_endpoint: ''
      TF_VAR_ENVIRONMENT: 'live'
    defaults:
      run:
        working-directory: ./infrastructure
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_KEY }}
          aws-region: ${{ vars.AWS_REGION }}
      - name: Set up Terraform
        uses: hashicorp/setup-terraform@v3
      - name: Retrieve AWS Account ID
        id: get-account-id
        run: |
          echo "ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)" >> $GITHUB_ENV
      - name: Create S3 state bucket if it doesn't exist
        run: |
          BUCKET_NAME="terraform-state-${{ env.TF_VAR_ENVIRONMENT }}-${{ env.AWS_REGION }}-${{ env.ACCOUNT_ID }}"
          if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>&1; then
            echo "Bucket $BUCKET_NAME already exists"
          else
            echo "Bucket $BUCKET_NAME does not exist, creating now..."
            aws s3api create-bucket --bucket "$BUCKET_NAME" --create-bucket-configuration LocationConstraint=${{ vars.AWS_REGION }}
            echo "Bucket $BUCKET_NAME created"
            echo "WAIT=true" >> $GITHUB_ENV
          fi
      - name: Create State Lock DynamoDB table if it doesnt exist
        run: |
          TABLE_NAME="terraform-state-lock"
          if aws dynamodb describe-table --table-name "$TABLE_NAME" 2>&1 | grep -q 'ResourceNotFoundException'; then
            echo "DynamoDB table $TABLE_NAME does not exist. Creating..."
            aws dynamodb create-table \
              --table-name "$TABLE_NAME" \
              --key-schema AttributeName=LockID,KeyType=HASH \
              --attribute-definitions AttributeName=LockID,AttributeType=S \
              --billing-mode
            echo "DynamoDB table $TABLE_NAME created. Enabling Point-In-Time Recovery..."
            aws dynamodb update-continuous-backups \
              --table-name "$TABLE_NAME" \
              --point-in-time-recovery-specification PointInTimeRecoveryEnabled=True
              echo "Point-In-Time Recovery enabled for $TABLE_NAME."
            echo "WAIT=true" >> $GITHUB_ENV
          else
            echo "DynamoDB table $TABLE_NAME already exists."
          fi
      - name: Wait after state resource creation
        if: env.WAIT == 'true'
        run: |
          echo "Waiting for resources to be fully consistent..."
          sleep 60 # Waits for 1 minute
      - name: Initialize Terraform for Main Infrastructure
        run: |
          terraform init -reconfigure \
          -backend-config="bucket=terraform-state-${{ env.TF_VAR_ENVIRONMENT }}-${{ vars.AWS_REGION }}-${{ env.ACCOUNT_ID }}" \
          -backend-config="region=${{ vars.AWS_REGION }}" \
          -backend-config="endpoint=https://s3.${{ vars.AWS_REGION }}.amazonaws.com" \
          -backend-config="dynamodb_endpoint=https://dynamodb.${{ vars.AWS_REGION }}.amazonaws.com" \
          -backend-config="sts_endpoint=https://sts.${{ vars.AWS_REGION }}.amazonaws.com"
      - name: Terraform Apply
        run: |
          terraform apply -auto-approve
```

The workflow will create a s3 bucket and table for state management. 

I also recommend creating a destroy workflow that destroys the environment when the commit message is `destroy`. You could do a `git commit --allow-empty -m 'destroy` and then push that.