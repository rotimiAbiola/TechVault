#!/bin/bash

# Development setup script
# This script sets up the development environment

set -e

echo "🚀 Setting up React-Python App Development Environment"

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker and try again."
    exit 1
fi

# Create .env file if it doesn't exist
if [ ! -f .env ]; then
    echo "📄 Creating .env file from template..."
    cp .env.example .env
    echo "✅ .env file created. Please update it with your configuration."
fi

# Build and start services
echo "🔨 Building and starting services..."
docker-compose up -d

# Wait for services to be ready
echo "⏳ Waiting for services to be ready..."
sleep 30

# Check service health
echo "🔍 Checking service health..."

services=("postgres:5432" "redis:6379" "elasticsearch:9200")
for service in "${services[@]}"; do
    host=$(echo $service | cut -d: -f1)
    port=$(echo $service | cut -d: -f2)
    
    if docker-compose exec $host nc -z localhost $port; then
        echo "✅ $host is ready"
    else
        echo "❌ $host is not ready"
    fi
done

# Initialize database
echo "🗄️ Initializing database..."
docker-compose exec backend python -c "
from app import app, db
with app.app_context():
    db.create_all()
    print('Database tables created successfully')
"

# Create Elasticsearch indices
echo "🔍 Setting up Elasticsearch indices..."
docker-compose exec backend python -c "
from elasticsearch import Elasticsearch
import json

es = Elasticsearch(['http://elasticsearch:9200'])

# Create products index
if not es.indices.exists(index='products'):
    mapping = {
        'mappings': {
            'properties': {
                'name': {'type': 'text', 'analyzer': 'standard'},
                'description': {'type': 'text', 'analyzer': 'standard'},
                'category': {'type': 'keyword'},
                'price': {'type': 'float'},
                'sku': {'type': 'keyword'},
                'stock_quantity': {'type': 'integer'},
                'is_active': {'type': 'boolean'},
                'created_at': {'type': 'date'},
                'owner': {'type': 'keyword'}
            }
        }
    }
    es.indices.create(index='products', body=mapping)
    print('Products index created')
else:
    print('Products index already exists')
"

# Install frontend dependencies and start development server
echo "📦 Installing frontend dependencies..."
cd frontend
npm install

echo "🎉 Development environment setup complete!"
echo ""
echo "📝 Next steps:"
echo "1. Update .env file with your configuration"
echo "2. Start frontend development server: cd frontend && npm run dev"
echo "3. Access the application:"
echo "   - Frontend: http://localhost:3000"
echo "   - Backend API: http://localhost:5000"
echo "   - Grafana: http://localhost:3001 (admin/admin)"
echo "   - Airflow: http://localhost:8080"
echo ""
echo "🔧 Useful commands:"
echo "   - View logs: docker-compose logs -f [service_name]"
echo "   - Stop services: docker-compose down"
echo "   - Rebuild services: docker-compose up --build"
