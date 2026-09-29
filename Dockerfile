# 4cus web build.
#
# Two stages: compile the Flutter web bundle with the real SDK, then serve the
# finished static files from nginx. The SDK is not in the final image, so the
# runtime stays small and has no build tooling in it.
#
# Build:  docker build -t 4cus-web .
# Run:    docker run -d -p 8080:80 4cus-web
#
# The Supabase URL and the publishable key are compiled into the bundle, so no
# runtime configuration or secrets are needed to serve it.

# --- Stage 1: build the web bundle -----------------------------------------
# Pinned to the same stable channel the releases are cut from. The repo's
# vercel.json still asks for 3.24.5, which predates the `withValues` colour API
# this code uses - the pinned version here is the one that actually builds.
FROM ghcr.io/cirruslabs/flutter:3.47.4 AS build

WORKDIR /app

# Dependency layer first, so editing Dart source does not re-download packages.
# pubspec.lock is copied rather than just pubspec.yaml: a release build must use
# the exact resolved versions, or the bundle differs from what shipped.
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .

# Same flags as the release workflow: no --dart-define, because the Supabase
# config and the Google client id are already compiled into the source.
# AOT-only is what makes a release web build tree-shakeable.
RUN flutter build web --release --no-web-resources-cdn

# --- Stage 2: serve it ------------------------------------------------------
FROM nginx:1.27-alpine

# Unprivileged nginx, so the container does not need to run as root.
RUN sed -i 's,^user .*,user 101;,/^user /d' /etc/nginx/nginx.conf \
 && sed -i 's,^pid /var/run/nginx.pid;,pid /tmp/nginx.pid;,' /etc/nginx/nginx.conf \
 && sed -i '/^pid /d' /etc/nginx/nginx.conf \
 && sed -i 's,/var/run/nginx.pid,/tmp/nginx.pid,g' /etc/nginx/nginx.conf

COPY --from=build /app/build/web /usr/share/nginx/html
COPY docker/nginx.conf /etc/nginx/conf.d/default.conf

USER 101

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --quiet --tries=1 --spider http://127.0.0.1/ || exit 1

CMD ["nginx", "-g", "daemon off;"]
