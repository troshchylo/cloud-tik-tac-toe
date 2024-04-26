FROM node:14-alpine AS build

WORKDIR /app

COPY package*.json ./

RUN npm install

RUN npm install -g http-server

COPY . .

CMD ["npm", "start"]