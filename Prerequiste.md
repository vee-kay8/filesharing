# Phase 0: Prerequiste
This document outlines the requirements needed before starting the project. 
## Getting Started

To get started with the project, follow these steps:

1. Install a code editor. For this project, VS-code was used
2. Install Terraform in your local sysytem:
   ```
    brew install hashicorp/tap/terraform
    ```
    Verify Installation
    ```
    terraform --version
    ```
3. Install Python3.x
    ```
    brew install python
    ```
    Verify Installation
    ```
    python3 --version
    pip3 --version
    ```
4. Install AWS CLI and configure with the appropriate permissions
    ```
    brew install awscli
    ```
    Verify Installation
    ```
    aws --version
    ```
    Configure with Appropriate PermissionsTo configure the CLI, you must first have Access Keys (an Access Key ID and Secret Access Key) associated with an IAM user that has the required permissions (policies) in your AWS account.
    * Create IAM Credentials <br>
        Security Best Practice: Do NOT use your AWS Root user credentials. Always create a dedicated IAM User with the least-privilege permissions necessary for the tasks you plan to perform.
        * Log in to the AWS Management Console.
        * Navigate to IAM (Identity and Access Management).
        * Create a new IAM User (or select an existing one).
        * Attach an IAM Policy to this user that grants the permissions you need 
        * On the user's Security credentials tab, create a new Access Key. Choose the Command Line Interface (CLI) option.
        * Crucially, save the Access Key ID and Secret Access Key displayed, as the Secret Key will not be shown again.
    * Run the Configuration CommandIn your Terminal, use the aws configure command. 
        ```
        aws configure
        ```
        You will be prompted to enter:
        * AWS Access Key 
        * AWS Secret Access.
        * Default region name
        * Default output 
    * Verify Credentials
        
        Run a simple command that requires credentials to confirm your setup is working and that your user has the necessary permissions.
        ```
        aws s3 ls
        aws sts get-caller-identity
        ```
        If successful, this will list your S3 buckets and which IAM identity the CLI is using


5. Clone the repository.

6. The Project will be using a module structure.
    
    In the `terrform/` folder, create folders and also maintain a general terraform folder there to bring up all the resources in this project.

    Create two files `main.tf` and `backend.tf` 

4. Follow the instructions in the `phases/` directory for detailed steps on each phase.

