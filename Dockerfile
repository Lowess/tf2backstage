FROM python:3.12-alpine

# optional: for local debugging
RUN apk add --no-cache bash jq yq

# exact versions that match what you used
# Copy requirements first for better caching
COPY requirements.txt /tmp/requirements.txt

# Install Python dependencies
RUN pip install --no-cache-dir -r /tmp/requirements.txt && rm /tmp/requirements.txt

WORKDIR /app

# Copy application files
COPY tf2backstage.j2 customize.py /app/

# the friendly CLI wrapper
COPY tf2backstage.sh /usr/local/bin/tf2backstage
RUN chmod +x /usr/local/bin/tf2backstage

# default working dir for volume mounts
WORKDIR /work
ENTRYPOINT ["tf2backstage"]
