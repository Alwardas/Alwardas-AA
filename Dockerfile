FROM rustlang/rust:nightly-slim as builder

WORKDIR /app

# Install dependencies
RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    protobuf-compiler \
    && rm -rf /var/lib/apt/lists/*

# Copy the backend source code
COPY backend/ /app/
# Copy protos (needed for build.rs)
COPY protos/ /protos/

# Build the release
RUN cargo build --release

# Runtime image
FROM debian:bookworm-slim
WORKDIR /app
RUN apt-get update && apt-get install -y ca-certificates libssl-dev && rm -rf /var/lib/apt/lists/*
COPY --from=builder /app/target/release/backend /app/backend
COPY --from=builder /app/migrations /app/migrations

CMD ["/app/backend"]
