FROM python:3.8.0-slim
WORKDIR /app
ADD . /app
RUN pip install --upgrade pip
RUN pip install -r requirements.txt
CMD exec gunicorn app:app --bind 0.0.0.0:$PORT --workers 1 --threads 8 --reload