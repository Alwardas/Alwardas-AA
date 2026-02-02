FROM rust:1.79-slim-bookworm as builder

WORKDIR /app

# Install dependencies
RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    protobuf-compiler \
    && rm -rf /var/lib/apt/lists/*

# Copy the entire backend directory into the container
# If the context is 'backend', this copies everything in backend/ to /app/
COPY . /app/

# Build the release
RUN cargo build --release

# Runtime image
FROM debian:bookworm-slim
WORKDIR /app
RUN apt-get update && apt-get install -y ca-certificates libssl-dev && rm -rf /var/lib/apt/lists/*
COPY --from=builder /app/target/release/backend /app/backend
COPY --from=builder /app/migrations /app/migrations

ENV PORT 3001
EXPOSE 3001
# We don't expose 5051 because Railway only allows 1 port
# Login was switched to HTTP (port 3001) so we are good.

CMD ["./backend"]
