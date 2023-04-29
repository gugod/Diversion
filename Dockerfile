FROM perl:5.36
RUN cpanm -n -q --no-man-pages App::cpm

COPY [".", "/app"]
WORKDIR /app

RUN cpm install -g
CMD perl -Ilib ./bin/diversion
