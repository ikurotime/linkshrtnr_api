# syntax=docker/dockerfile:1

# Comments are provided throughout this file to help you get started.
# If you need more help, visit the Dockerfile reference guide at
# https://docs.docker.com/go/dockerfile-reference/

ARG RUST_VERSION=1.74.0
ARG APP_NAME=linkshrtnr-rust-api

################################################################################
# xx is a helper for cross-compilation.
# See https://github.com/tonistiigi/xx/ for more information.
FROM --platform=$BUILDPLATFORM tonistiigi/xx:1.3.0 AS xx

################################################################################
# Create a stage for building the application.
FROM --platform=$BUILDPLATFORM rust:${RUST_VERSION}-alpine AS build
ARG APP_NAME
WORKDIR /app

COPY /templates /app/templates
COPY /migrations /app/migrations
# Copy cross-compilation utilities from the xx stage.
COPY --from=xx / /

# Install host build dependencies.
RUN apk add --no-cache clang lld musl-dev git file

# This is the architecture you’re building for, which is passed in by the builder.
# Placing it here allows the previous steps to be cached across architectures.
ARG TARGETPLATFORM

# Install cross-compilation build dependencies.
RUN xx-apk add --no-cache musl-dev gcc

# Build the application.
# Leverage a cache mount to /usr/local/cargo/registry/
# for downloaded dependencies, a cache mount to /usr/local/cargo/git/db
# for git repository dependencies, and a cache mount to /app/target/ for 
# compiled dependencies which will speed up subsequent builds.
# Leverage a bind mount to the src directory to avoid having to copy the
# source code into the container. Once built, copy the executable to an
# output directory before the cache mounted /app/target is unmounted.
RUN --mount=type=bind,source=src,target=src \
    --mount=type=bind,source=Cargo.toml,target=Cargo.toml \
    --mount=type=bind,source=Cargo.lock,target=Cargo.lock \
    --mount=type=cache,target=/app/target/,id=rust-cache-${APP_NAME}-${TARGETPLATFORM} \
    --mount=type=cache,target=/usr/local/cargo/git/db \
    --mount=type=cache,target=/usr/local/cargo/registry/ \
    <<EOF
set -e
xx-cargo build --locked --release --target-dir ./target
cp ./target/$(xx-cargo --print-target-triple)/release/$APP_NAME /bin/server
xx-verify /bin/server
EOF

FROM node:buster-slim as node_builder

WORKDIR /app

# we'll use pnpm to ensure we're consistent across the dev and release environments
RUN corepack enable

# copy on over all the dependencies
COPY tailwind.config.js .
COPY styles /app/styles
COPY assets /app/assets
# we'll also copy the templates over so tailwind can scan for unused class utilities, omitting them from the final output
COPY templates /app/templates

# build our css
RUN pnpm dlx tailwindcss -i ./styles/tailwind.css -o /app/assets/main.css

# stage 3, copy over our build artifacts and run
# We do not need the Rust toolchain to run the binary!
FROM debian:buster-slim AS runtime

WORKDIR /app

# we'll copy over the executable from our server builder and the compiled tailwind assets separately - layer caching FTW!
COPY --from=build /bin/server /bin/
COPY --from=node_builder /app/assets ./assets
COPY --from=node_builder /app/templates ./templates

################################################################################
# Create a new stage for running the application that contains the minimal
# runtime dependencies for the application. This often uses a different base
# image from the build stage where the necessary files are copied from the build
# stage.
#
# The example below uses the alpine image as the foundation for running the app.
# By specifying the "3.18" tag, it will use version 3.18 of alpine. If
# reproducability is important, consider using a digest
# (e.g., alpine@sha256:664888ac9cfd28068e062c991ebcff4b4c7307dc8dd4df9e728bedde5c449d91).
FROM alpine:3.18 AS final

# Create a non-privileged user that the app will run under.
# See https://docs.docker.com/go/dockerfile-user-best-practices/
ARG UID=10001
RUN adduser \
    --disabled-password \
    --gecos "" \
    --home "/nonexistent" \
    --shell "/sbin/nologin" \
    --no-create-home \
    --uid "${UID}" \
    appuser
USER appuser

# Copy the executable from the "build" stage.
COPY --from=build /bin/server /bin/
COPY --from=node_builder /app/assets ./assets
COPY --from=node_builder /app/templates ./templates

# Expose the port that the application listens on.
EXPOSE 3000 

# What the container should run when it is started.
CMD ["/bin/server"]
