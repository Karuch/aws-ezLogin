# aws-ezLogin

aws-ezLogin is a script that automate the installation of AWS CLI (v2),
create a profile for your IAM user (persistent cerdentials you are using to send API requests to AWS),
and assume a role that your IAM user have access to.
and all of those in a single command!

## Getting Started

[Download linux bash compatible script](https://github.com/Karuch/aws-ezLogin/blob/main/linux/bash/cli-login.sh)
[Download windows powershell compatible script](https://github.com/Karuch/aws-ezLogin/blob/main/windows/powershell/cli-login.ps1)

 or

 Clone the repo:
```bash
git clone git@github.com:Karuch/aws-ezLogin
```


## Usage

### Linux bash script:

```bash
chmod +X cli-login.sh
```

Must be executed using `source`!
```bash
source ./cli-login.sh \
  --aws-key <AccessKey> \
  --aws-secret <SecretKey> \
  --region <Region e.g il-central-1> \
  --profile <IamUserName e.g talk> \
  --role-name <roleName> \
  --account-id <accountId e.g 012345678910>
```
then you'll be asked to prompt the IAM user's MFA code.
check you assumed the role successfully:
```bash
aws sts get-caller-identity
```

### Windows powershell script:

must be executed via powershell terminal!
cmd might not work.
```powershell
powershell -ExecutionPolicy Bypass -File .\cli-login.ps1 `
  -awsKey <AccessKey> `
  -awsSecret <SecretKey> `
  -region <Region e.g. il-central-1> `
  -profile <IamUserName e.g. talk> `
  -roleName <roleName> `
```
then you'll be asked to prompt the IAM user's MFA code.

if executed successfully a new profile should be created by the name of your IAM user
you should be able to see it there:
```bash
aws configure list-profiles
```
then switch to the newly created profile:
```powershell
$env:AWS_PROFILE = '<profile name>'
```
check that you assumed the role successfully:
```bash
aws sts get-caller-identity
```


## Contributing

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/Feature`)
3. Commit your Changes (`git commit -m 'Add some feature'`)
4. Push to the Branch (`git push origin feature/Feature`)
5. Open a Pull Request

## License

Distributed under the Apache License 2.0. See `LICENSE.txt` for more information.

## Contact

Email: talk474747@gmail.com
Linkedin: [www.linkedin.com/in/tal-karucci](https://www.linkedin.com/in/tal-karucci-678286290)
Project Link: [github.com/Karuch/aws-ezLogin](https://github.com/Karuch/aws-ezLogin)
