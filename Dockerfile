FROM python:3.9

RUN apt-get update && apt-get install -y --no-install-recommends git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY ./requirements.txt ./

RUN python3 -m venv .venv && \
    .venv/bin/pip3 install --no-cache-dir --upgrade pip && \
    .venv/bin/pip3 install --no-cache-dir -r requirements.txt

COPY ./ ./
RUN chmod +x /app/start.sh

EXPOSE 8000

ENTRYPOINT ["/app/start.sh"]
