FROM python:3.7.0-slim
ENV APP_HOME /app
WORKDIR $APP_HOME
COPY . ./
RUN pip install FLASK gunicorn
CMD exec gunicorn --bind :$PORT --workers 1 --threads 8 app:app