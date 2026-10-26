FROM rabbitmq:4.2-management

# Official delayed-message plugin supports RabbitMQ 4.2.x only.
# https://github.com/rabbitmq/rabbitmq-delayed-message-exchange/releases/tag/v4.2.0
ARG PLUGIN_VERSION=4.2.0

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends curl ca-certificates; \
    curl -fsSL \
      -o "${RABBITMQ_HOME}/plugins/rabbitmq_delayed_message_exchange-${PLUGIN_VERSION}.ez" \
      "https://github.com/rabbitmq/rabbitmq-delayed-message-exchange/releases/download/v${PLUGIN_VERSION}/rabbitmq_delayed_message_exchange-${PLUGIN_VERSION}.ez"; \
    chown rabbitmq:rabbitmq "${RABBITMQ_HOME}/plugins/rabbitmq_delayed_message_exchange-${PLUGIN_VERSION}.ez"; \
    rabbitmq-plugins enable --offline rabbitmq_delayed_message_exchange; \
    apt-get purge -y --auto-remove curl; \
    rm -rf /var/lib/apt/lists/*
