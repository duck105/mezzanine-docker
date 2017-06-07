FROM python:3.6
ENV PYTHONUNBUFFERED 1
RUN mkdir /code
WORKDIR /code
ADD manage.py /code/
ADD requirements.txt /code/
ADD /mezzanine_docker/local_settings.py /code/
RUN pip install -r requirements.txt
ADD . /code/
