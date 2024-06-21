# Use an official Python runtime as a parent image
FROM python:3.10.8-slim

# Set the working directory in the container
WORKDIR /app

# Copy the current directory contents into the container at /usr/src/app
COPY sense-collector.py .
COPY storage.py .
COPY requirements.txt .

# Install any needed packages specified in requirements.txt

RUN apt-get update && \
    apt-get install -y gcc python3-dev python3-pip && \
    rm -rf /var/lib/apt/lists/*

RUN python3 -m pip install --no-cache-dir --upgrade pip \
&& python3 -m pip install --no-cache-dir -r /app/requirements.txt

# Run script.py when the container launches
CMD ["python3", "./sense-collector.py"]
