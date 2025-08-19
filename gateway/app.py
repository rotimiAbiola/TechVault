from flask import Flask, request, jsonify
from flask_cors import CORS
import requests
import os
import logging
from urllib.parse import urljoin

app = Flask(__name__)
CORS(app)

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Service URLs
SERVICES = {
    'auth': os.getenv('AUTH_SERVICE_URL', 'http://auth-service:5001'),
    'products': os.getenv('PRODUCT_SERVICE_URL', 'http://product-service:5002'),
    'cart': os.getenv('CART_SERVICE_URL', 'http://cart-service:5003'),
    'payment': os.getenv('PAYMENT_SERVICE_URL', 'http://payment-service:5004'),
    'orders': os.getenv('ORDER_SERVICE_URL', 'http://order-service:5005')
}

def forward_request(service_name, path):
    """Forward request to the appropriate microservice"""
    try:
        service_url = SERVICES.get(service_name)
        if not service_url:
            return jsonify({'error': f'Service {service_name} not found'}), 404
        
        url = urljoin(service_url, path)
        
        # Forward headers (especially Authorization)
        headers = {key: value for key, value in request.headers if key != 'Host'}
        
        # Forward the request
        response = requests.request(
            method=request.method,
            url=url,
            headers=headers,
            data=request.get_data(),
            params=request.args,
            timeout=30
        )
        
        return response.content, response.status_code, response.headers.items()
        
    except requests.exceptions.RequestException as e:
        logger.error(f"Error forwarding request to {service_name}: {str(e)}")
        return jsonify({'error': 'Service unavailable'}), 503

# Auth service routes
@app.route('/api/auth/<path:path>', methods=['GET', 'POST', 'PUT', 'DELETE'])
def auth_proxy(path):
    return forward_request('auth', f'/api/auth/{path}')

@app.route('/api/register', methods=['POST'])
def register_proxy():
    return forward_request('auth', '/api/register')

@app.route('/api/login', methods=['POST'])
def login_proxy():
    return forward_request('auth', '/api/login')

@app.route('/api/profile', methods=['GET', 'PUT'])
def profile_proxy():
    return forward_request('auth', '/api/profile')

# Product service routes (public access)
@app.route('/api/products', methods=['GET'])
def products_list_proxy():
    return forward_request('products', '/api/products')

@app.route('/api/products/<path:path>', methods=['GET'])
def products_proxy(path):
    return forward_request('products', f'/api/products/{path}')

# Cart service routes
@app.route('/api/cart', methods=['GET', 'DELETE'])
def cart_main_proxy():
    return forward_request('cart', '/api/cart')

@app.route('/api/cart/<path:path>', methods=['GET', 'POST', 'PUT', 'DELETE'])
def cart_proxy(path):
    return forward_request('cart', f'/api/cart/{path}')

# Payment service routes
@app.route('/api/payment/<path:path>', methods=['GET', 'POST', 'PUT', 'DELETE'])
def payment_proxy(path):
    return forward_request('payment', f'/api/payment/{path}')

# Order service routes
@app.route('/api/orders', methods=['GET', 'POST'])
def orders_main_proxy():
    return forward_request('orders', '/api/orders')

@app.route('/api/orders/<path:path>', methods=['GET', 'POST', 'PUT', 'DELETE'])
def orders_proxy(path):
    return forward_request('orders', f'/api/orders/{path}')

# Health check
@app.route('/health')
def health():
    """Gateway health check"""
    service_status = {}
    overall_healthy = True
    
    for service_name, service_url in SERVICES.items():
        try:
            response = requests.get(f"{service_url}/health", timeout=5)
            service_status[service_name] = {
                'status': 'healthy' if response.status_code == 200 else 'unhealthy',
                'response_time': response.elapsed.total_seconds()
            }
        except Exception as e:
            service_status[service_name] = {
                'status': 'unhealthy',
                'error': str(e)
            }
            overall_healthy = False
    
    return jsonify({
        'status': 'healthy' if overall_healthy else 'unhealthy',
        'services': service_status,
        'gateway': 'healthy'
    }), 200 if overall_healthy else 503

# API Health check (for frontend)
@app.route('/api/health')
def api_health():
    """API health check endpoint for frontend"""
    return health()
    
    return jsonify({
        'status': 'healthy' if overall_healthy else 'unhealthy',
        'services': service_status,
        'gateway': 'healthy'
    }), 200 if overall_healthy else 503

if __name__ == '__main__':
    port = int(os.getenv('PORT', 5000))
    app.run(host='0.0.0.0', port=port, debug=False)
