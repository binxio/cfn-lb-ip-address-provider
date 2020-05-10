include Makefile.mk

NAME=cfn-lb-ip-address-provider
S3_BUCKET_PREFIX=binxio-public
AWS_REGION=eu-central-1
S3_BUCKET=$(S3_BUCKET_PREFIX)-$(AWS_REGION)
ALL_REGIONS=$(shell aws --region $(AWS_REGION) \
		ec2 describe-regions 		\
		--query 'join(`\n`, Regions[?RegionName != `$(AWS_REGION)`].RegionName)' \
		--output text)

help:
	@echo 'make                 - builds a zip file to target/.'
	@echo 'make release         - builds a zip file and deploys it to s3.'
	@echo 'make clean           - the workspace.'
	@echo 'make test            - execute the tests, requires a working AWS connection.'
	@echo 'make deploy-provider - deploys the provider.'
	@echo 'make delete-provider - deletes the provider.'
	@echo 'make demo            - deploys the provider and the demo cloudformation stack.'
	@echo 'make delete-demo     - deletes the demo cloudformation stack.'

deploy: target/$(NAME)-$(VERSION).zip
	aws s3 --region $(AWS_REGION) \
		cp target/$(NAME)-$(VERSION).zip \
		s3://$(S3_BUCKET_PREFIX)-$(AWS_REGION)/lambdas/$(NAME)-$(VERSION).zip 
	aws s3 --region $(AWS_REGION) cp \
		s3://$(S3_BUCKET_PREFIX)-$(AWS_REGION)/lambdas/$(NAME)-$(VERSION).zip \
		s3://$(S3_BUCKET_PREFIX)-$(AWS_REGION)/lambdas/$(NAME)-latest.zip 
	aws s3api --region $(AWS_REGION) \
		put-object-acl --bucket $(S3_BUCKET_PREFIX)-$(AWS_REGION) \
		--acl public-read --key lambdas/$(NAME)-$(VERSION).zip 
	aws s3api --region $(AWS_REGION) \
		put-object-acl --bucket $(S3_BUCKET_PREFIX)-$(AWS_REGION) \
		--acl public-read --key lambdas/$(NAME)-latest.zip 

deploy-all-regions: deploy
	@for REGION in $(ALL_REGIONS); do \
		echo "copying to region $$REGION.." ; \
		aws s3 --region $$REGION \
			cp  --acl public-read \
			--source-region $(AWS_REGION) \
			s3://$(S3_BUCKET)/lambdas/$(NAME)-$(VERSION).zip \
			s3://$(S3_BUCKET_PREFIX)-$$REGION/lambdas/$(NAME)-$(VERSION).zip; \
		aws s3 --region $$REGION \
			cp  --acl public-read \
			--source-region $(AWS_REGION) \
			s3://$(S3_BUCKET)/lambdas/$(NAME)-$(VERSION).zip \
			s3://$(S3_BUCKET_PREFIX)-$$REGION/lambdas/$(NAME)-latest.zip; \
	done
		

undeploy:
	@for REGION in $(ALL_REGIONS); do \
                echo "removing lamdba from region $$REGION.." ; \
                aws s3 --region $(AWS_REGION) \
                        rm  \
                        s3://$(S3_BUCKET_PREFIX)-$$REGION/lambdas/$(NAME)-$(VERSION).zip; \
        done


do-push: deploy

do-build: target/$(NAME)-$(VERSION).zip

target/$(NAME)-$(VERSION).zip: src/*.py requirements.txt
	mkdir -p target/content 
	docker build --build-arg ZIPFILE=$(NAME)-$(VERSION).zip -t $(NAME)-lambda:$(VERSION) -f Dockerfile.lambda . && \
		ID=$$(docker create $(NAME)-lambda:$(VERSION) /bin/true) && \
		docker export $$ID | (cd target && tar -xvf - $(NAME)-$(VERSION).zip) && \
		docker rm -f $$ID && \
		chmod ugo+r target/$(NAME)-$(VERSION).zip

venv: requirements.txt
	virtualenv -p python3 venv  && \
	. ./venv/bin/activate && \
	pip3 --quiet install --upgrade pip && \
	pip3 --quiet install -r requirements.txt 
	
clean:
	rm -rf venv target src/*.pyc tests/*.pyc

test: venv
	for n in ./cloudformation/*.yaml ; do aws cloudformation validate-template --template-body file://$$n ; done
	for n in ./cloudformation/*.yaml ; do cfn-lint $$n ; done
	. ./venv/bin/activate && \
	pip --quiet install -r test-requirements.txt && \
	cd src && \
	PYTHONPATH=$(PWD)/src pytest ../tests/test*.py 

autopep:
	autopep8 --experimental --in-place --max-line-length 132 src/*.py tests/*.py

deploy-provider: COMMAND=$(shell if aws cloudformation get-template-summary --stack-name $(NAME) >/dev/null 2>&1; then \
			echo update; else echo create; fi)
deploy-provider: 
	aws cloudformation $(COMMAND)-stack \
                --capabilities CAPABILITY_IAM \
                --stack-name $(NAME) \
                --template-body file://cloudformation/cfn-resource-provider.yaml \
                --parameters \
                        ParameterKey=S3BucketPrefix,ParameterValue=$(S3_BUCKET_PREFIX) \
                        ParameterKey=CFNCustomProviderZipFileName,ParameterValue=lambdas/$(NAME)-latest.zip
	aws cloudformation wait stack-$(COMMAND)-complete  --stack-name $(NAME)

delete-provider:
	aws cloudformation delete-stack --stack-name $(NAME)
	aws cloudformation wait stack-delete-complete  --stack-name $(NAME)

demo: COMMAND=$(shell if aws cloudformation get-template-summary --stack-name $(NAME)-demo >/dev/null 2>&1; then echo update; else echo create; fi)
demo: VPC_ID=$(shell aws ec2  --output text --query 'Vpcs[?IsDefault].VpcId' describe-vpcs)
demo: SUBNET_IDS=$(shell aws ec2 --output text --query 'RouteTables[?Routes[?GatewayId == null]].Associations[].SubnetId' describe-route-tables --filters Name=vpc-id,Values=$(VPC_ID) | tr '\t' ',')
demo: 
	if [[ -z $(VPC_ID) ]] || [[ -z $(SUBNET_IDS) ]]; then \
		echo "ERROR: Either there is no default VPC in your account or no subnets" && exit 1 ; \
	else \
		echo "using Subnet ID $(SUBNET_IDS)"; \
	fi
	aws cloudformation $(COMMAND)-stack --stack-name $(NAME)-demo \
                --template-body file://cloudformation/demo-stack.yaml \
		--parameters "ParameterKey=VPC,ParameterValue=$(VPC_ID)"  \
			     "ParameterKey=Subnets,ParameterValue=\"$(SUBNET_IDS)\""
	aws cloudformation wait stack-$(COMMAND)-complete  --stack-name $(NAME)-demo

delete-demo:
	aws cloudformation delete-stack --stack-name $(NAME)-demo 
	aws cloudformation wait stack-delete-complete  --stack-name $(NAME)-demo

deploy-pipeline: 
	aws cloudformation deploy \
                --capabilities CAPABILITY_IAM \
                --stack-name $(NAME)-pipeline \
                --template-file ./cloudformation/cicd-pipeline.yaml \
                --parameter-overrides \
                        S3BucketPrefix=$(S3_BUCKET_PREFIX)

delete-pipeline: 
	aws cloudformation delete-stack --stack-name $(NAME)-pipeline
	aws cloudformation wait stack-delete-complete  --stack-name $(NAME)-pipeline

