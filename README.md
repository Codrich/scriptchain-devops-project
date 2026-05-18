# ScriptChain Health – DevOps Project

**Candidate:** Richard Kweku Addae
**Position:** Linux DevOps Engineer Intern – Summer 2026
**Submitted:** May 2026

---

## Repository Structure
scriptchain-devops-assignment/
├── README.md
├── cloudformation/
│   └── stack.yaml          # Task 1 – S3 bucket + EC2 instance
├── gitlab-ci/
│   └── .gitlab-ci.yml      # Task 2 – Node.js CI/CD pipeline
└── lambda/
├── handler.py           # Task 3 – Lambda function handler
├── requirements.txt     #          Runtime dependencies
├── setup.py             #          Python package configuration
└── build.sh             #          Package and deploy script

---

## Task 1 · CloudFormation Template

**File:** `cloudformation/stack.yaml`

### What it provisions

| Resource             | Type                        | Purpose                                |
|----------------------|-----------------------------|----------------------------------------|
| `ScriptChainBucket`  | `AWS::S3::Bucket`           | Artifact and data storage              |
| `EC2SecurityGroup`   | `AWS::EC2::SecurityGroup`   | SSH (22) and HTTP (80) ingress         |
| `EC2S3Role`          | `AWS::IAM::Role`            | Least-privilege S3 read for EC2        |
| `EC2InstanceProfile` | `AWS::IAM::InstanceProfile` | Attaches IAM role to EC2               |
| `ScriptChainEC2`     | `AWS::EC2::Instance`        | Amazon Linux 2023, Apache bootstrapped |

### Key design decisions

- **Parameterized** – `EnvironmentName`, `InstanceType`, and `AllowedSSHCidr` are runtime parameters, making the template reusable across dev / staging / prod without modification.
- **No hardcoded AMI IDs** – A `Mappings` block resolves the correct Amazon Linux 2023 AMI per region, so the template works across `us-east-1`, `us-east-2`, and `us-west-2` without manual changes.
- **IAM role instead of static credentials** – The EC2 instance uses an instance profile with a scoped-down policy (S3 `GetObject` + `ListBucket` only), following AWS security best practices.
- **S3 security** – Versioning, AES-256 encryption at rest, and a full public-access block are enabled by default.
- **Outputs with Exports** – `BucketName`, `BucketArn`, and `EC2PublicIP` are exported so other stacks can reference them without hard-coding values.

### Deploy

```bash
aws cloudformation deploy \
  --template-file cloudformation/stack.yaml \
  --stack-name scriptchain-dev \
  --parameter-overrides \
      EnvironmentName=dev \
      KeyPairName=<your-key-pair> \
      AllowedSSHCidr=<your-ip>/32 \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1
```

---

## Task 2 · GitLab CI/CD Pipeline

**File:** `gitlab-ci/.gitlab-ci.yml`

### Pipeline overview
build ──► test:unit        ──► deploy:staging     (auto, on push to main)
└──► test:integration └──► deploy:production (manual gate, on semver tag)

| Stage  | Job                 | Trigger                | Notes                                               |
|--------|---------------------|------------------------|-----------------------------------------------------|
| build  | `build`             | All branches + tags    | `npm ci`, lint, compile → passes `dist/` artifact   |
| test   | `test:unit`         | After build            | Jest + coverage → Cobertura report for GitLab badge |
| test   | `test:integration`  | After build            | Runs in parallel with unit tests                    |
| deploy | `deploy:staging`    | Push to `main`         | S3 sync → SSH → PM2 restart                         |
| deploy | `deploy:production` | Semver tag (`v*.*.*`)  | Same as staging, **manual approval required**       |

### Key design decisions

- **Artifact passing** – `dist/` and `node_modules/` passed from `build` to downstream jobs so dependencies are never reinstalled twice.
- **`needs:` chaining** – `test` jobs start immediately after `build` completes, reducing overall pipeline time.
- **Manual production gate** – `when: manual` means a human must click "Run" in GitLab before code reaches production, preventing accidental deploys.
- **Environment promotion** – Staging deploys on every `main` push; production only on tagged releases (`v1.0.0`, `v2.3.1`, etc.).
- **PM2 process management** – `pm2 restart || pm2 start` restarts the app if running, or starts it fresh if not.

### Required CI/CD variables

Set these in **GitLab → Settings → CI/CD → Variables** (mask sensitive values):

| Variable                | Description                      |
|-------------------------|----------------------------------|
| `AWS_ACCESS_KEY_ID`     | IAM access key                   |
| `AWS_SECRET_ACCESS_KEY` | IAM secret *(mask)*              |
| `AWS_DEFAULT_REGION`    | e.g. `us-east-1`                 |
| `S3_BUCKET_NAME`        | Artifact storage bucket          |
| `EC2_HOST_STAGING`      | Staging server IP or hostname    |
| `EC2_HOST_PROD`         | Production server IP or hostname |
| `EC2_SSH_KEY`           | Private SSH key *(mask)*         |
| `EC2_USER`              | SSH user (e.g. `ec2-user`)       |

---

## Task 3 · AWS Lambda Python Package

**Directory:** `lambda/`

### Files

| File               | Purpose                                                                    |
|--------------------|----------------------------------------------------------------------------|
| `handler.py`       | Lambda entry point – parses API Gateway events, returns structured JSON    |
| `requirements.txt` | Pinned runtime dependencies (`boto3` excluded – provided by the runtime)   |
| `setup.py`         | Python package manifest for local development installs and CI tooling      |
| `build.sh`         | Packages dependencies + handler into `function.zip` and optionally deploys |

### Key design decisions

- **`boto3` excluded from `requirements.txt` and `setup.py`** – The Lambda runtime provides it, so bundling it bloats the deployment package unnecessarily.
- **`setup.py` `extras_require["dev"]`** – Dev dependencies (`pytest`, `moto`) declared separately so they are never accidentally bundled into the Lambda zip.
- **`build.sh` idempotent deploy** – Checks whether the function exists and calls `update-function-code` or `create-function` accordingly, so the same script works in both fresh and update scenarios.
- **Structured error handling in `handler.py`** – Separate `except` blocks for `JSONDecodeError` (400) and generic exceptions (500) ensure the caller always receives a well-formed response.

### Build and deploy

```bash
cd lambda
chmod +x build.sh

# Build only – produces function.zip
./build.sh

# Build + deploy (create or update)
export LAMBDA_FUNCTION_NAME=scriptchain-health-api
export LAMBDA_ROLE_ARN=arn:aws:iam::<account-id>:role/<execution-role>
./build.sh deploy

# Local development install
pip install -e ".[dev]"
```

---

## Technologies

AWS CloudFormation · Amazon S3 · Amazon EC2 · AWS IAM · AWS Lambda
GitLab CI/CD · Node.js · Python 3.12 · Bash · PM2 · Apache

---

## Author

Richard Kweku Addae
AWS Certified Solutions Architect – Associate | CompTIA Security+ | Linux+ | AZ-900 | AWS Certifiied Security Speiclaty - On-going |
