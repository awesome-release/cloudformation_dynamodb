FROM public.ecr.aws/aws-cli/aws-cli

RUN mkdir -p /cftemplates
WORKDIR /cftemplates

COPY *.yaml .

ENTRYPOINT ["/bin/sh", "-c", "aws"]
