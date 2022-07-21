# build stage
FROM rocker/geospatial as rbuilder
RUN --mount=type=secret, id=mysecret ./build-script.sh

ENV DBNAME=XXXXXX
ENV HOST=XXXXXX
ENV PORT=XXXXXX
ENV USER=XXXXXX
ENV PASSWORD=XXXXXX

WORKDIR /app

## Install remaining packages from source
COPY requirements-src.R ./
RUN Rscript requirements-src.R

COPY StateoftheDB.Rmd ./
RUN mkdir ./outputs
RUN Rscript -e "rmarkdown::render('StateoftheDB.Rmd', output_file='outputs/index.html', runtime='static', clean=TRUE)"

# production stage
FROM nginx as production-stage
RUN mkdir /app
COPY --from=rbuilder ./outputs /app
COPY nginx.conf /etc/nginx/nginx.conf
