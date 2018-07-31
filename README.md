# cfn-lb-ip-address-provider
A CloudFormation custom resource provider for obtaining the IP addresses of an ELB.

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
The IP addresses of the Load Balancer are returned as the `PrivateIpAddresses` attribute. It is an array of IP addresses in CIDR notation.



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
aws cloudformation create-stack --stack-name cfn-lb-ip-address-provider-demo \
	--template-body file://cloudformation/demo-stack.json
aws cloudformation wait stack-create-complete  --stack-name cfn-lb-ip-address-provider-demo
```

## Conclusion
With this custom CloudFormation Provider you can obtain the IP addresses of a network load balancer in order to 
create security groups to allow the health checks to be performed.
