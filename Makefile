include Makefile.mk

USERNAME=xebia
NAME=cfn-lb-ip-address-provider

AWS_REGION=eu-central-1
AWS_ACCOUNT=$(shell aws sts get-caller-identity --query Account --output text)
REGISTRY_HOST=$(AWS_ACCOUNT).dkr.ecr.$(AWS_REGION).amazonaws.com
IMAGE=$(REGISTRY_HOST)/$(USERNAME)/$(NAME)
TAG_WITH_LATEST=never


requirements.txt test-requirements.txt: Pipfile.lock
	pipenv requirements > requirements.txt
	pipenv requirements --dev-only > test-requirements.txt

Pipfile.lock: Pipfile
	pipenv update

test: Pipfile.lock
	for n in ./cloudformation/*.yaml ; do aws cloudformation validate-template --template-body file://$$n ; done
	PYTHONPATH=$(PWD)/src pipenv run pytest ./tests/test*.py

pre-build: requirements.txt


fmt:
	black src/*.py tests/*.py

deploy-provider:  ## deploy the provider to the current account
	sed -i '' -e 's^$(NAME):[0-9]*\.[0-9]*\.[0-9]*[^\.]*^$(NAME):$(VERSION)^' cloudformation/cfn-resource-provider.yaml
	aws cloudformation deploy \
                --stack-name $(NAME) \
                --capabilities CAPABILITY_IAM \
                --template-file ./cloudformation/cfn-resource-provider.yaml

delete-provider:   ## delete provider from the current account
	aws cloudformation delete-stack --stack-name $(NAME)
	aws cloudformation wait stack-delete-complete  --stack-name $(NAME)



deploy-pipeline:   ## deploy the CI/CD pipeline
	aws cloudformation deploy \
                --stack-name $(NAME)-pipeline \
                --capabilities CAPABILITY_IAM \
                --template-file ./cloudformation/cicd-pipeline.yaml \
		--parameter-overrides Name=$(NAME)

delete-pipeline:   ## delete the CI/CD pipeline
	aws cloudformation delete-stack --stack-name $(NAME)-pipeline
	aws cloudformation wait stack-delete-complete  --stack-name $(NAME)-pipeline

demo: VPC_ID=$(shell aws ec2  --output text --query 'Vpcs[?IsDefault].VpcId' describe-vpcs)
demo: SUBNET_IDS=$(shell aws ec2 describe-subnets --output text --query 'Subnets[?DefaultForAz].SubnetId' --filters Name=vpc-id,Values=$(VPC_ID) | tr '\t' ',')
demo:		   ## deploy the demo
	if [[ -z $(VPC_ID) ]] || [[ -z $(SUBNET_IDS) ]]; then \
	       echo "ERROR: Either there is no default VPC in your account or no subnets" && exit 1 ; \
	else \
	       echo "using Subnet ID $(SUBNET_IDS)"; \
	fi
	aws cloudformation deploy \
		--stack-name $(NAME)-demo \
		--capabilities CAPABILITY_NAMED_IAM \
		--template-file ./cloudformation/demo-stack.yaml \
		--parameter-overrides "VPC=$(VPC_ID)" "Subnets=$(SUBNET_IDS)"

delete-demo:	   ## delete the demo
	aws cloudformation delete-stack --stack-name $(NAME)-demo
	aws cloudformation wait stack-delete-complete  --stack-name $(NAME)-demo

ecr-login:	   ## login to the ECR repository
	aws ecr get-login-password --region $(AWS_REGION) | \
	docker login --username AWS --password-stdin $(REGISTRY_HOST)
