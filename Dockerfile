FROM docker.io/library/node:22-alpine AS build
WORKDIR /app
COPY package.json package-lock.json .npmrc ./
RUN npm ci
COPY . .
RUN npm run build

FROM docker.io/library/nginx:1.27-alpine
# The nginx image runs envsubst on /etc/nginx/templates/*.template at startup.
COPY nginx.conf.template /etc/nginx/templates/default.conf.template
RUN rm -rf /usr/share/nginx/html/*
COPY --from=build /app/build /usr/share/nginx/html
ENV BACKEND_URL=http://backend:5000
EXPOSE 80
