# Official Dart image: https://hub.docker.com/_/dart
# Specify the Dart SDK base image version using dart:<version> (ex: dart:2.12)
FROM dart:stable AS build
# tzdata provides /usr/share/zoneinfo, copied into the final scratch image below.
RUN apt-get update \
    && apt-get install -y --no-install-recommends libsqlite3-dev tzdata \
    && rm -rf /var/lib/apt/lists/*
# Resolve app dependencies.
WORKDIR /hitomi
COPY pubspec.* ./
RUN dart pub get
# Copy app source code and AOT compile it.
COPY . .
# Ensure packages are still up-to-date if anything has changed
RUN dart pub get --offline
RUN dart run build_runner build
RUN dart build cli -t bin/main.dart -o build/cli/linux_x64
# Local time zone for the app's timestamps (note the capital S in Shanghai).
RUN ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime \
    && echo "Asia/Shanghai" > /etc/timezone
# Build minimal serving image from AOT-compiled `/bin/main` and required system
# libraries and configuration files stored in `/runtime/` from the build stage.
FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /hitomi/build/cli/linux_x64/bundle/bin/main /bin/main
COPY --from=build /hitomi/build/cli/linux_x64/bundle/lib/libsqlite3.so /lib/libsqlite3.so
# Time zone data: /etc/localtime is a symlink into /usr/share/zoneinfo, so both
# must be copied for it to keep resolving inside the scratch image.
COPY --from=build /usr/share/zoneinfo /usr/share/zoneinfo
COPY --from=build /etc/localtime /etc/localtime
COPY --from=build /etc/timezone /etc/timezone
EXPOSE 7890/tcp
# Start server.
ENTRYPOINT ["/bin/main"]
