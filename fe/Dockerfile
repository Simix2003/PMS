FROM ghcr.io/cirruslabs/flutter:3.27.0 AS build

# Create non-root user
RUN useradd -ms /bin/bash flutteruser

WORKDIR /app

COPY . .

RUN chown -R flutteruser:flutteruser /app
# Make both Flutter directories "safe" for git
RUN git config --global --add safe.directory /sdks/flutter \
    && git config --global --add safe.directory /flutter

# Give permissions to the flutteruser on the Flutter SDK folders
RUN chown -R flutteruser:flutteruser /sdks/flutter || true \
    && chown -R flutteruser:flutteruser /flutter || true

# Change user
USER flutteruser

RUN flutter --version
RUN flutter config --no-analytics --no-cli-animations
RUN flutter config --enable-web
RUN flutter pub get

RUN flutter pub get

# Define different entry points
ARG TARGET
ARG BASE_HREF  # Add this line

RUN echo "Building for target: $TARGET"

RUN if [ "$TARGET" = "home" ]; then \
        flutter build web --web-renderer html --release -t lib/main_home.dart -o build/web; \
    elif [ "$TARGET" = "data" ]; then \
        flutter build web --web-renderer html --release -t lib/main_data.dart -o build/web; \
    elif [ "$TARGET" = "stringatrici" ]; then \
        flutter build web --web-renderer html --release -t lib/main_stringatrici.dart -o build/web; \
    elif [ "$TARGET" = "visual" ]; then \
        flutter build web --web-renderer html --release -t lib/main_visual.dart -o build/web; \
    else \
        echo "Invalid TARGET.  Must be home, data, stringatrici or visual."; \
        exit 1; \
    fi

FROM nginx:alpine

RUN rm /etc/nginx/conf.d/default.conf

# Install gettext for envsubst
RUN apk add --no-cache gettext

# Create directories
RUN mkdir -p /usr/share/nginx/html

# Copy the built web app
COPY --from=build /app/build/web /usr/share/nginx/html

# Copy the index.html and use envsubst to replace the variable
COPY web/index.html /usr/share/nginx/html/index.html
RUN envsubst '$BASE_HREF' < /usr/share/nginx/html/index.html > /usr/share/nginx/html/temp.html && \
    mv /usr/share/nginx/html/temp.html /usr/share/nginx/html/index.html

COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]