### Important prerequisite : An S3 bucket by the name of lambda-dummy-code should already exist in the target AWS account. The lambda-dummy-code bucket should contain a dummy-lambda-code.zip file in its root. The zip file should contain a plain text file by the name of init.txt in it. The init.txt can be empty or can contain any text in it.

## The makeup of this terraform code has been intentionally spilt to separate Infrastructure Deployment from Code deployment
When a '**terraform apply**' is performed on this code, the lambda is created with a dummy code base (an Init.txt file with some simple text in it)

It is assumed that the valid lambda python code is available in the transporter-px-loader-lambda.py python code file
After the '**terraform apply**' is successfuly, do the following to upload the actual lambda python code along with its correct boto3 dependency.

### Instructions to bundle boto3 version 1.37.4 with lambda python code
In your project root folder, execute the following sequence of commands on the command prompt or shell prompt:
1. python3 -m venv .venv 
2. source .venv/bin/activate 
3. pip install boto3==1.37.4  
4. mkdir lambda-zip-assembly 
5. cp transporter-px-loader-lambda.py ./lambda-zip-assembly  
6. cp -r .venv/lib/python3.9/site-packages/* ./lambda-zip-assembly 
7. cd lambda-zip-assembly 
8. zip -r transporter-px-loader-lambda.zip .   
9. aws lambda update-function-code --function-name transporter-px-loader-lambda --zip-file fileb://transporter-px-loader-lambda.zip