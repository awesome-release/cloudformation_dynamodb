FROM public.ecr.aws/aws-cli/aws-cli

RUN mkdir -p /cftemplates
WORKDIR /cftemplates

COPY *.yaml .

CMD ["aws", "cloudformation"]
