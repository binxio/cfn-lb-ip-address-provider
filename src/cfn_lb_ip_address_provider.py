import logging
import os
import re
from uuid import uuid4

import boto3
from cfn_resource_provider import ResourceProvider

log = logging.getLogger()
log.setLevel(level=os.getenv('LOG_LEVEL', 'INFO'))

request_schema = {
    "type": "object",
    "required": ["LoadBalancerArn"],
    "properties": {
        "LoadBalancerArn": {
            "type": "string",
            "description": "to obtain the IP addresses for",
            "pattern": "arn:aws:elasticloadbalancing:[^:]*:[^:]*:loadbalancer/.*"
        },
        "Format": {
            "type": "string",
            "description": "of the IP address",
            "enum": ["plain", "cidr"],
            "default": "cidr"
        }
    }
}


class LBIpAddressProvider(ResourceProvider):

    def __init__(self):
        super(LBIpAddressProvider, self).__init__()

    @property
    def ec2(self):
        return boto3.client('ec2')

    @property
    def load_balancer_arn(self):
        return self.get('LoadBalancerArn')

    def format(self, address):
        return f'{address}/32' if self.get('Format', 'cidr') == 'cidr' else f'{address}'

    def ensure_physical_resource_id(self):
        if not self.physical_resource_id:
            self.physical_resource_id = '{}'.format(uuid4())

    def get_private_ip_addresses(self):
        self.ensure_physical_resource_id()
        m = re.match(r'arn:aws:elasticloadbalancing:(?P<region>[^:]*):(?P<account>[^:]*):loadbalancer/(?P<id>.*)',
                     self.load_balancer_arn)
        if m:
            response = self.ec2.describe_network_interfaces(
                Filters=[{'Name': 'description', 'Values': ['ELB {}'.format(m.group('id'))]}])
            ip_addresses = [self.format(address['PrivateIpAddress']) for addresses in
                            map(lambda i: i['PrivateIpAddresses'], response['NetworkInterfaces']) for address in
                            addresses]
            self.set_attribute('PrivateIpAddresses', ip_addresses)
            if not ip_addresses:
                self.fail('no network interfaces found for load balancer {}'.format(self.load_balancer_arn))
        else:
            self.fail('Invalid LoadBalancerArn {}'.format(self.load_balancer_arn))

    def create(self):
        self.get_private_ip_addresses()

    def update(self):
        self.get_private_ip_addresses()

    def delete(self):
        pass


provider = LBIpAddressProvider()


def handler(request, context):
    return provider.handle(request, context)
