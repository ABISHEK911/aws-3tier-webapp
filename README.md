# AWS 3-Tier Web App — Terraform + IAM Least Privilege

A production-style 3-tier architecture on AWS, built from scratch with Terraform.
Built as a portfolio project for AWS Cloud Solutions Architect roles, with a
deliberate focus on IAM least-privilege design and secure network segmentation.
## Architecture
<p align="center">
  <img src="https://raw.githubusercontent.com/ABISHEK911/aws-3tier-webapp/main/aws-3tier-architecture.png" alt="AWS 3-Tier Web Application Architecture" width="850">
</p>
 ##Tiers

- **Web tier:** Application Load Balancer in public subnets — the only component exposed to the internet.
- **App tier:** EC2 instances in an Auto Scaling Group, deployed in private subnets behind the ALB. They use a NAT Gateway for outbound updates only, with no inbound internet access.
- **Data tier:** Amazon RDS MySQL in private subnets with no route to the internet. It is accessible only from the application tier security group.
## Why this design 

- **Security groups are chained, not opened wide.** Each tier's SG only allows traffic from the SG of the tier in front of it (ALB → App → DB), never a raw CIDR block except for the ALB's public :80 listener.
- **No SSH keys, no open port 22, anywhere.** Instances are managed via **AWS Systems Manager Session Manager** instead. The IAM role grants `AmazonSSMManagedInstanceCore`, so instances can be accessed through the AWS Console/CLI without ever opening an inbound SSH port.
- **IMDSv2 enforced** (`http_tokens = "required"`) on the launch template — blocks the classic SSRF-to-credential-theft attack path that IMDSv1 is vulnerable to.
- **IAM least privilege.** The EC2 instance role (`iam.tf`) has no AdministratorAccess. It can only:
  1. Write logs to *this project's specific* CloudWatch log group (scoped by ARN, not `*`)
  2. Be managed via SSM

  This avoids the common anti-pattern of attaching a broad managed policy "to make things work."
- **DB subnets have zero internet route.** Not just "no public IP" — the private DB route table has no `0.0.0.0/0` route at all, so even a compromised instance in that subnet can't reach the internet.
- **Auto Scaling with target tracking** on CPU means the app tier scales itself rather than being sized for peak load 24/7.
- **Secrets hygiene**: DB password is never in `.tf` files — it's passed via a `TF_VAR_db_password` environment variable at apply time and never committed to version control.

## Prerequisites

- Terraform >= 1.5.0
- AWS CLI configured (`aws configure`) with an IAM user that has sufficient permissions to create VPCs, EC2, RDS, IAM roles, etc.
- An AWS account (most of this stays within free tier — see Cost Notes below for the two exceptions)

## Deployment

1. **Set your DB password as an environment variable** (never put it in a file):

   PowerShell (Windows):
   ```powershell
   $env:TF_VAR_db_password = "YourStrongPassword123!"
   ```

   Mac/Linux:
   ```bash
   export TF_VAR_db_password="YourStrongPassword123!"
   ```

2. **Initialize Terraform:**
   ```bash
   terraform init
   ```

3. **Review the plan:**
   ```bash
   terraform plan
   ```

4. **Apply:**
   ```bash
   terraform apply
   ```
   Type `yes` when prompted. This takes roughly 8–12 minutes — RDS is the slow part, often 5-10 minutes on its own.

5. **Test it**: once apply finishes, get the load balancer's public address:
   ```bash
   aws elbv2 describe-load-balancers --names 3tier-webapp-alb --query "LoadBalancers[0].DNSName" --output text
   ```
   Paste that into a browser (`http://`, not `https://` — no TLS cert configured in this project). Give the instance a couple of minutes to finish booting and pass its health check first.

## Tearing it down

**Important** — RDS and NAT Gateway both cost money by the hour. Don't leave this running.

```bash
terraform destroy
```
Type `yes` when prompted.

## Cost notes

This stays close to AWS free tier, but two things are **not** free-tier eligible:
- **NAT Gateway**: ~$0.045/hour + data processing charges (~$1/day if left running)
- **RDS**, if left running past free tier hours

For a portfolio demo: spin it up, test it, take screenshots, then `terraform destroy` the same day.

## A couple of real deployment gotchas (kept here on purpose)

Building this surfaced a few AWS quirks worth knowing for interviews — the kind of thing you only learn by actually deploying, not by reading docs:

- **RDS identifiers and subnet group names must start with a letter, not a digit.** A project name like `3tier-webapp` fails RDS naming validation even though it's a perfectly valid string everywhere else in this project. Worked around by giving the RDS resources their own literal names instead of deriving them from the shared project name variable.
- **Free tier instance eligibility shifts over time.** `t2.micro` is the classic "free tier" answer, but newer accounts are free-tier eligible on `t3.micro` instead — the ASG will fail with a clear `FreeTierRestrictionError`-style message if you pick wrong.
- **Free tier also caps RDS backup retention.** Requesting `backup_retention_period = 7` failed under free tier; `1` day worked. Worth checking current limits before assuming a "sensible default" will apply cleanly.

## Project structure

| File | Purpose |
|---|---|
| `provider.tf` | Terraform + AWS provider configuration |
| `variables.tf` | Input variables, including the sensitive `db_password` |
| `vpc.tf` | VPC, subnets (public/app/db), IGW, NAT, route tables |
| `security_groups.tf` | Tier-to-tier security group chaining |
| `iam.tf` | Least-privilege EC2 instance role and policies |
| `alb.tf` | Application Load Balancer, target group, listener |
| `ec2.tf` | Launch template + Auto Scaling Group for app tier |
| `rds.tf` | RDS MySQL instance in isolated DB subnets |
| `cloudwatch.tf` | Log group the app tier is scoped to write to |
| `outputs.tf` | ALB DNS name, VPC ID, DB endpoint, IAM role ARN |
| `user_data.sh` | Bootstrap script installing nginx on each instance |

## Possible extensions

- Add HTTPS via ACM certificate + Route 53 domain
- Add WAF in front of the ALB
- Add a CI/CD pipeline (CodePipeline/CodeBuild) to deploy app code automatically
- Enable Multi-AZ on RDS and document the failover behavior
- Run the IAM role's policy through the AWS IAM Policy Simulator and document exactly what it can/cannot do
