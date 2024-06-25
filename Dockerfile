# Use an official Python runtime as a parent image
FROM python:3.12.3-slim

# Set the working directory in the container
WORKDIR /app

# Copy the current directory contents into the container at /app
COPY sense-collector.py .
COPY storage.py .
COPY requirements.txt .

# Install pip and the Python packages
RUN python3 -m pip install --no-cache-dir --upgrade pip \
    && python3 -m pip install --no-cache-dir -r requirements.txt

# Run sense-collector.py when the container launches
CMD ["python3", "./sense-collector.py"]
