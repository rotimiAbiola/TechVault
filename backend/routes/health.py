from flask import Blueprint, jsonify
from models.models import db
from elasticsearch import Elasticsearch
import redis
import os

health_bp = Blueprint('health', __name__)

@health_bp.route('/health', methods=['GET'])
def health_check():
    """Comprehensive health check endpoint"""
    health_status = {
        'status': 'healthy',
        'timestamp': None,
        'services': {}
    }
    
    overall_status = True
    
    # Database health check
    try:
        from sqlalchemy import text
        db.session.execute(text('SELECT 1'))
        health_status['services']['database'] = {
            'status': 'healthy',
            'message': 'Database connection successful'
        }
    except Exception as e:
        health_status['services']['database'] = {
            'status': 'unhealthy',
            'message': f'Database connection failed: {str(e)}'
        }
        overall_status = False
    
    # Elasticsearch health check
    try:
        es_url = os.getenv('ELASTICSEARCH_URL', 'http://localhost:9200')
        es = Elasticsearch([es_url])
        es.cluster.health()
        health_status['services']['elasticsearch'] = {
            'status': 'healthy',
            'message': 'Elasticsearch connection successful'
        }
    except Exception as e:
        health_status['services']['elasticsearch'] = {
            'status': 'unhealthy',
            'message': f'Elasticsearch connection failed: {str(e)}'
        }
        overall_status = False
    
    # Redis health check
    try:
        redis_url = os.getenv('REDIS_URL', 'redis://localhost:6379/0')
        r = redis.from_url(redis_url)
        r.ping()
        health_status['services']['redis'] = {
            'status': 'healthy',
            'message': 'Redis connection successful'
        }
    except Exception as e:
        health_status['services']['redis'] = {
            'status': 'unhealthy',
            'message': f'Redis connection failed: {str(e)}'
        }
        overall_status = False
    
    # Set overall status
    health_status['status'] = 'healthy' if overall_status else 'unhealthy'
    
    from datetime import datetime
    health_status['timestamp'] = datetime.utcnow().isoformat()
    
    status_code = 200 if overall_status else 503
    return jsonify(health_status), status_code

@health_bp.route('/readiness', methods=['GET'])
def readiness_check():
    """Kubernetes readiness probe"""
    try:
        # Check if the application is ready to serve traffic
        db.session.execute('SELECT 1')
        return jsonify({'status': 'ready'}), 200
    except Exception:
        return jsonify({'status': 'not ready'}), 503

@health_bp.route('/liveness', methods=['GET'])
def liveness_check():
    """Kubernetes liveness probe"""
    # Simple check to see if the application is alive
    return jsonify({'status': 'alive'}), 200
