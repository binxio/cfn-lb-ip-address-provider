import pytest
import uuid
import re
from cfn_lb_ip_address_provider import LBIpAddressProvider, handler


@pytest.fixture
def ec2():
    LBIpAddressProvider.ec2 = DummyEC2()
    return LBIpAddressProvider.ec2


def test_get_address(ec2):
    request = Request('Create')
    response = handler(request, {})
    assert response['Status'], 'SUCCESS'
    assert 'PhysicalResourceId' in response
    assert 'PrivateIpAddresses' in response['Data']
    assert len(response['Data']['PrivateIpAddresses']) == 2
    for i in response['Data']['PrivateIpAddresses']:
        assert re.match(r'[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*/32', i)

    request = Request('Update', 'dsdfsdsfdsdfsdsdffs')
    response = handler(request, {})
    assert 'PhysicalResourceId' in response
    assert response['Status'], 'SUCCESS'

    request = Request('Delete', 'dsdfsdsfdsdfsdsdffs')
    response = handler(request, {})
    assert response['Status'], 'SUCCESS'


class Request(dict):

    def __init__(self, request_type, physical_resource_id=None):
        self.update({
            'RequestType': request_type,
            'ResponseURL': 'https://httpbin.org/put',
            'StackId': 'arn:aws:cloudformation:us-west-2:EXAMPLE/stack-name/guid',
            'RequestId': 'request-%s' % uuid.uuid4(),
            'ResourceType': 'Custom::LBIpAddress',
            'LogicalResourceId': 'MyIpAddresses',
            'ResourceProperties': {
                'LoadBalancerArn': 'arn:aws:elasticloadbalancing:eu-central-1:123456890:loadbalancer/net/dev-api-crdb-nw-lb/9684452bb394ec26'
            }})
        if physical_resource_id is not None:
            self['PhysicalResourceId'] = physical_resource_id


class DummyEC2(object):

    def describe_network_interfaces(self, **kwargs):
        return {
            "NetworkInterfaces": [
                {
                    "Status": "in-use",
                    "MacAddress": "02:2f:8f:b0:cf:75",
                    "SourceDestCheck": True,
                    "VpcId": "vpc-a01106c2",
                    "Description": "my network interface",
                    "Association": {
                        "PublicIp": "203.0.113.12",
                        "AssociationId": "eipassoc-0fbb766a",
                        "PublicDnsName": "ec2-203-0-113-12.compute-1.amazonaws.com",
                        "IpOwnerId": "123456789012"
                    },
                    "NetworkInterfaceId": "eni-e5aa89a3",
                    "PrivateIpAddresses": [
                        {
                            "PrivateDnsName": "ip-10-0-1-17.ec2.internal",
                            "Association": {
                                "PublicIp": "203.0.113.12",
                                "AssociationId": "eipassoc-0fbb766a",
                                "PublicDnsName": "ec2-203-0-113-12.compute-1.amazonaws.com",
                                "IpOwnerId": "123456789012"
                            },
                            "Primary": True,
                            "PrivateIpAddress": "10.0.1.17"
                        }
                    ],
                    "RequesterManaged": False,
                    "Ipv6Addresses": [],
                    "PrivateDnsName": "ip-10-0-1-17.ec2.internal",
                    "AvailabilityZone": "us-east-1d",
                    "Attachment": {
                        "Status": "attached",
                        "DeviceIndex": 1,
                        "AttachTime": "2013-11-30T23:36:42.000Z",
                        "InstanceId": "i-1234567890abcdef0",
                        "DeleteOnTermination": False,
                        "AttachmentId": "eni-attach-66c4350a",
                        "InstanceOwnerId": "123456789012"
                    },
                    "Groups": [
                        {
                            "GroupName": "default",
                            "GroupId": "sg-8637d3e3"
                        }
                    ],
                    "SubnetId": "subnet-b61f49f0",
                    "OwnerId": "123456789012",
                    "TagSet": [],
                    "PrivateIpAddress": "10.0.1.17"
                },
                {
                    "Status": "in-use",
                    "MacAddress": "02:58:f5:ef:4b:06",
                    "SourceDestCheck": True,
                    "VpcId": "vpc-a01106c2",
                    "Description": "Primary network interface",
                    "Association": {
                        "PublicIp": "198.51.100.0",
                        "IpOwnerId": "amazon"
                    },
                    "NetworkInterfaceId": "eni-f9ba99bf",
                    "PrivateIpAddresses": [
                        {
                            "Association": {
                                "PublicIp": "198.51.100.0",
                                "IpOwnerId": "amazon"
                            },
                            "Primary": True,
                            "PrivateIpAddress": "10.0.1.149"
                        }
                    ],
                    "RequesterManaged": False,
                    "Ipv6Addresses": [],
                    "AvailabilityZone": "us-east-1d",
                    "Attachment": {
                        "Status": "attached",
                        "DeviceIndex": 0,
                        "AttachTime": "2013-11-30T23:35:33.000Z",
                        "InstanceId": "i-0598c7d356eba48d7",
                        "DeleteOnTermination": True,
                        "AttachmentId": "eni-attach-1b9db777",
                        "InstanceOwnerId": "123456789012"
                    },
                    "Groups": [
                        {
                            "GroupName": "default",
                            "GroupId": "sg-8637d3e3"
                        }
                    ],
                    "SubnetId": "subnet-b61f49f0",
                    "OwnerId": "123456789012",
                    "TagSet": [],
                    "PrivateIpAddress": "10.0.1.149"
                }
            ]
        }
