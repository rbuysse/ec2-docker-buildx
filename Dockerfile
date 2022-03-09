FROM ubuntu:focal

RUN apt-get update && apt-get install -yq --no-install-recommends \
    python3 \
    python3-pip \
 && pip3 install \
    botocore \
    boto3 \
    requests

COPY aws.py /aws.py

ENTRYPOINT ["/aws.py"]
