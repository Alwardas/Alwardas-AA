# Stage 1: Flutter Web Builder
FROM debian:bookworm-slim AS flutter-builder

RUN apt-get update && apt-get install -y curl git unzip xz-utils libglu1-mesa
WORKDIR /flutter
RUN git clone https://github.com/flutter/flutter.git -b stable .
ENV PATH="/flutter/bin:$PATH"
RUN flutter doctor

WORKDIR /app
COPY frontend/ .
RUN flutter build web --release

# Stage 2: Rust Backend Builder
FROM rustlang/rust:nightly-slim AS rust-builder

WORKDIR /app

# Install backend dependencies
RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    protobuf-compiler \
    && rm -rf /var/lib/apt/lists/*

# Copy backend source and protos
COPY backend/ /app/
COPY protos/ /protos/

# Build the release
RUN cargo build --release

# Stage 3: Final Runtime Image
FROM debian:bookworm-slim
WORKDIR /app

# Install runtime dependencies
RUN apt-get update && apt-get install -y ca-certificates libssl-dev && rm -rf /var/lib/apt/lists/*

# Copy the backend binary and migrations
COPY --from=rust-builder /app/target/release/backend /app/backend
COPY --from=rust-builder /app/migrations /app/migrations

# Copy the built Flutter web files to the "static" directory
COPY --from=flutter-builder /app/build/web /app/static

# Set the binary as the entry point
CMD ["/app/backend"]
