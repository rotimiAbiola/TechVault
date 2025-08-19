import os
import time
from datetime import timedelta
from flask import Flask, jsonify, request, g
from flask_migrate import Migrate
from flask_cors import CORS
from flask_jwt_extended import JWTManager
from celery import Celery
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Import db from models to avoid circular imports
from models.models import db

# Initialize extensions
migrate = Migrate()
jwt = JWTManager()

# Prometheus metrics (initialize these only once)
try:
    from prometheus_client import generate_latest, Counter, Histogram
    REQUEST_COUNT = Counter('http_requests_total', 'Total HTTP requests', ['method', 'endpoint', 'status'])
    REQUEST_DURATION = Histogram('http_request_duration_seconds', 'HTTP request duration')
except Exception:
    # If metrics already exist, get them from registry
    from prometheus_client import REGISTRY, generate_latest
    REQUEST_COUNT = None
    REQUEST_DURATION = None
    for collector in list(REGISTRY._collector_to_names.keys()):
        if hasattr(collector, '_name'):
            if collector._name == 'http_requests_total':
                REQUEST_COUNT = collector
            elif collector._name == 'http_request_duration_seconds':
                REQUEST_DURATION = collector

def make_celery(app):
    """Create Celery instance"""
    celery = Celery(
        app.import_name,
        backend=app.config['CELERY_RESULT_BACKEND'],
        broker=app.config['CELERY_BROKER_URL']
    )
    celery.conf.update(app.config)
    
    class ContextTask(celery.Task):
        def __call__(self, *args, **kwargs):
            with app.app_context():
                return self.run(*args, **kwargs)
    
    celery.Task = ContextTask
    return celery

def create_app(config_name='development'):
    """Application factory"""
    app = Flask(__name__)
    
    # Configuration
    app.config.update(
        # Database
        SQLALCHEMY_DATABASE_URI=os.getenv('DATABASE_URL', 'postgresql://postgres:postgres@localhost:5432/appdb'),
        SQLALCHEMY_TRACK_MODIFICATIONS=False,
        
        # JWT
        JWT_SECRET_KEY=os.getenv('JWT_SECRET_KEY', 'your-super-secret-jwt-key'),
        JWT_ACCESS_TOKEN_EXPIRES=timedelta(hours=24),
        JWT_REFRESH_TOKEN_EXPIRES=timedelta(days=30),
        
        # Celery
        CELERY_BROKER_URL=os.getenv('REDIS_URL', 'redis://localhost:6379/0'),
        CELERY_RESULT_BACKEND=os.getenv('REDIS_URL', 'redis://localhost:6379/0'),
        
        # Elasticsearch
        ELASTICSEARCH_URL=os.getenv('ELASTICSEARCH_URL', 'http://localhost:9200'),
        
        # Snowflake
        SNOWFLAKE_ACCOUNT=os.getenv('SNOWFLAKE_ACCOUNT'),
        SNOWFLAKE_USER=os.getenv('SNOWFLAKE_USER'),
        SNOWFLAKE_PASSWORD=os.getenv('SNOWFLAKE_PASSWORD'),
        SNOWFLAKE_WAREHOUSE=os.getenv('SNOWFLAKE_WAREHOUSE'),
        SNOWFLAKE_DATABASE=os.getenv('SNOWFLAKE_DATABASE'),
        SNOWFLAKE_SCHEMA=os.getenv('SNOWFLAKE_SCHEMA'),
    )
    
    # Initialize extensions
    db.init_app(app)
    migrate.init_app(app, db)
    jwt.init_app(app)
    CORS(app, origins=["http://localhost:3000", "http://localhost:80"])
    
    # Request middleware for metrics
    @app.before_request
    def before_request():
        app.start_time = time.time()
    
    @app.after_request
    def after_request(response):
        REQUEST_COUNT.labels(
            method=request.method,
            endpoint=request.endpoint or 'unknown',
            status=response.status_code
        ).inc()
        
        if hasattr(app, 'start_time'):
            REQUEST_DURATION.observe(time.time() - app.start_time)
        
        return response
    
    # Register blueprints
    from routes.auth import auth_bp
    from routes.products import products_bp
    from routes.analytics import analytics_bp
    from routes.health import health_bp
    
    app.register_blueprint(auth_bp, url_prefix='/api/auth')
    app.register_blueprint(products_bp, url_prefix='/api/products')
    app.register_blueprint(analytics_bp, url_prefix='/api/analytics')
    app.register_blueprint(health_bp, url_prefix='/api')
    
    # Prometheus metrics endpoint
    @app.route('/metrics')
    def metrics():
        return generate_latest()
    
    # Error handlers
    @app.errorhandler(404)
    def not_found(error):
        return jsonify({'error': 'Not found'}), 404
    
    @app.errorhandler(500)
    def internal_error(error):
        db.session.rollback()
        return jsonify({'error': 'Internal server error'}), 500
    
    return app

# Create app instance
app = create_app()

# Create Celery instance
celery = make_celery(app)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
