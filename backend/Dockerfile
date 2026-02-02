# Builder stage
FROM rust:1.79-slim-bookworm as builder

WORKDIR /app

# Install build dependencies
RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    protobuf-compiler \
    && rm -rf /var/lib/apt/lists/*

# Copy all files from the current directory (backend)
# Copy source code
COPY . .

# Create dummy src/main.rs to build dependencies and cache them
# We need to handle the build logic carefully because we have unique build.rs
# For simplicity, we'll just copy the source and build directly.
# Optimizing docker cache for Rust is complex with tonic-build.
COPY . .

# Build the application
RUN cargo build --release

# Runtime stage
FROM debian:bookworm-slim

WORKDIR /app

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    ca-certificates \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy the binary from builder
COPY --from=builder /app/target/release/backend /app/backend
# Copy migrations if needed at runtime (depends on how you run migrations)
COPY --from=builder /app/migrations /app/migrations
# Copy proto files if needed (unlikely for runtime unless dynamic)
# COPY --from=builder /app/proto /app/proto 

EXPOSE 3001
EXPOSE 50051

CMD ["./backend"]
