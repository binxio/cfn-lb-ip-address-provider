# Custom::AMI
The `Custom::LBIpAddress` resource is a lookup resource which returns the private IP address of Application 
and Network Load Balancers.

## Syntax
To obtain the private ip addresses of the load balancers in your AWS CloudFormation template, use the following syntax:

```yaml
  Type : "Custom::LBIpAddress",
  Properties:
    LoadBalancerArn: Arn
    ServiceToken: String
```

## Properties
You can specify the following properties:

- `LoadBalancerArn`  - The arn of the load balancer.

The custom resource wraps the EC2 [describe-network-interfaces](https://docs.aws.amazon.com/cli/latest/reference/ec2/describe-network-interfaces.html) function
and searches for network interfaces with the ARN name of the load balancer in the description.

## Return values
With 'Fn::GetAtt' the following values are available:

- `PrivateIpAddresses` - array of private ip address of the Load Balancer, in /32 CIDR notation

### Caveat 
- this resource depends on the informal link between the Load Balancer and the Network Interface based on the name of the description in the network interface. If AWS changes this, the provider will break.

- ipv6 addresses are not yet returned.
