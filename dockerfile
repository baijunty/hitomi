# Official Dart image: https://hub.docker.com/_/dart
# Specify the Dart SDK base image version using dart:<version> (ex: dart:2.12)
FROM dart:stable AS build
RUN apt-get  update && apt-get install -y libsqlite3-dev
# Resolve app dependencies.
WORKDIR /hitomi
COPY pubspec.* ./
RUN dart pub get
# Copy app source code and AOT compile it.
COPY . .
# Ensure packages are still up-to-date if anything has changed
RUN dart pub get --offline
RUN dart compile exe bin/main.dart -o bin/hitomi
RUN echo "Asia/shanghai" > /etc/timezone

# Build minimal serving image from AOT-compiled `/server` and required system
# libraries and configuration files stored in `/runtime/` from the build stage.
FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /usr/lib/x86_64-linux-gnu/libsqlite3* /usr/lib/x86_64-linux-gnu/
COPY --from=build /hitomi/bin/hitomi /bin/hitomi
EXPOSE 7890/tcp
# Start server.
ENTRYPOINT ["/bin/hitomi"]
