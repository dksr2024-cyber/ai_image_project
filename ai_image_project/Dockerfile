# ប្រើ Python ស្តង់ដារ
FROM python:3.10-slim

# ដំឡើងបណ្ណាល័យ System ដែល AI ត្រូវការ
RUN apt-get update && apt-get install -y \
    libgl1-mesa-glx \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# កំណត់ Folder ធ្វើការ
WORKDIR /app

# ចម្លងកូដចូល
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# បញ្ជាឱ្យ Run
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "10000"]