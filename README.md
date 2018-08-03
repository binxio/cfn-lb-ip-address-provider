# cfn-lb-ip-address-provider
A CloudFormation custom resource provider for obtaining the IP addresses of an AWS Network Load Balancer.

In order for the network load balancer to execute a Health Check, an ingress rule
must be specified. As the ip addresses of the load balancers cannot be obtained and you cannot associate a security group with 
a Network Load Balancer, you would need to grant access to entire subnet network range in which 
the network load balancer is deployed.

With this custom CloudFormation Provider you can obtain the actual private ip addresses of the
load balancers, so you can explicitly grant access to these load balancers.


## How do get the IP addresses of a Load Balancer?
It is quite easy: you specify a CloudFormation resource of the [Custom::LBIpAddresses](docs/Custom::LBIpAddresses.md), as follows:

```yaml
  LBIpAddresses:
    Type: Custom::LBIpAddresses
    Properties:
      LoadBalancerArn: !Ref NetworkLoadBalancer
      ServiceToken: !Sub 'arn:aws:lambda:${AWS::Region}:${AWS::AccountId}:function:binxio-cfn-lb-ip-address-provider'

Outputs:
  PrivateIpAddresses:
    Type: String
    Value: !Ref LBIpAddresses.PrivateIpAddresses
      
```

The IP addresses of the Load Balancer are returned as the `PrivateIpAddresses` attribute. It is an array of IP addresses in CIDR notation. You may
use these values to create a security group as shown below:

```yaml
  LoadBalancerHealthCheckSecurityGroup:
    Type: AWS::EC2::SecurityGroup
    Properties:
      GroupDescription: !Sub 'load balancer'
      VpcId: !Ref 'VPC'
      SecurityGroupIngress:
        - Description: lb health check
          IpProtocol: tcp
          FromPort: 443
          ToPort: 443
          CidrIp: !Select [ 0, !GetAtt 'Ips.PrivateIpAddresses']
        - Description: lb health check
          IpProtocol: tcp
          FromPort: 443
          ToPort: 443
          CidrIp: !Select [ 1, !GetAtt 'Ips.PrivateIpAddresses']
        - Description: lb health check
          IpProtocol: tcp
          FromPort: 443
          ToPort: 443
          CidrIp: !Select [ 2, !GetAtt 'Ips.PrivateIpAddresses']
      Tags:
        - Key: Name
          Value: !Sub 'load balancer health checks'
```

## Caveats
This resource depends on the informal link between the Load Balancer and the Network Interface based on the name of the description in the network interface.  If AWS changes this, this provider will break.


## Installation
To install this custom resource, type:

```sh
aws cloudformation create-stack \
	--capabilities CAPABILITY_IAM \
	--stack-name cfn-lb-ip-address-provider \
	--template-body file://cloudformation/cfn-lb-ip-address-provider.json 

aws cloudformation wait stack-create-complete  --stack-name cfn-lb-ip-address-provider 
```

This CloudFormation template will use our pre-packaged provider from `s3://binxio-public-${AWS_REGION}/lambdas/cfn-lb-ip-address-provider-0.2.1.zip`.


## Demo
To install the simple sample of the Custom Resource, type:

```sh
VPC_ID=$(aws ec2  --output text --query 'Vpcs[?IsDefault].VpcId' describe-vpcs)
SUBNET_IDS=$(aws ec2 --output text --query 'RouteTables[?Routes[?GatewayId == null]].Associations[].SubnetId' describe-route-tables --filters Name=vpc-id,Values=$VPC_ID | tr '\t' ',')
aws cloudformation create-stack --stack-name cfn-lb-ip-address-demo \
	--template-body file://cloudformation/demo-stack.yaml \
	--parameters "ParameterKey=VPC,ParameterValue=$VPC_ID"  \
		     "ParameterKey=Subnets,ParameterValue=\"$SUBNET_IDS\""
aws cloudformation wait stack-create-complete  --stack-name cfn-lb-ip-address-demo
```

## Conclusion
With this custom CloudFormation Provider you can create security groups which allow the Network Load Balancer to perform the health checks, without 
opening the port up to a whole set of subnet ranges. You can use the exact ip addresses of that load balancer.
