from flask import Blueprint, jsonify, request
from flask_jwt_extended import jwt_required, get_jwt_identity

products_bp = Blueprint('products', __name__)

@products_bp.route('/demo', methods=['GET'])
def get_demo_products():
    """Get demo products without authentication - for testing TechVault"""
    # TechVault electronics demo data
    products = [
        {'id': 1, 'name': 'iPhone 15 Pro Max', 'price': 1199.99, 'description': 'Latest iPhone with titanium design, A17 Pro chip, and advanced camera system'},
        {'id': 2, 'name': 'MacBook Pro 16"', 'price': 2499.99, 'description': 'M3 Max chip, 36GB unified memory, 1TB SSD - Perfect for professionals'},
        {'id': 3, 'name': 'PlayStation 5', 'price': 499.99, 'description': 'Next-gen gaming console with ultra-high speed SSD and 3D audio'},
        {'id': 4, 'name': 'Samsung Galaxy S24 Ultra', 'price': 1299.99, 'description': 'AI-powered smartphone with S Pen, 200MP camera, and titanium build'},
        {'id': 5, 'name': 'iPad Pro 12.9"', 'price': 1099.99, 'description': 'M2 chip, Liquid Retina XDR display, and Apple Pencil compatibility'},
        {'id': 6, 'name': 'AirPods Pro (3rd Gen)', 'price': 249.99, 'description': 'Active noise cancellation, spatial audio, and USB-C charging'},
        {'id': 7, 'name': 'Dell XPS 13', 'price': 999.99, 'description': 'Ultra-portable laptop with Intel Core i7, 16GB RAM, and InfinityEdge display'},
        {'id': 8, 'name': 'Nintendo Switch OLED', 'price': 349.99, 'description': 'Vibrant OLED screen, enhanced audio, and versatile gaming modes'}
    ]
    return jsonify({
        'products': products,
        'total': len(products)
    })

@products_bp.route('/', methods=['GET'])
def get_products_public():
    """Get all products - public access for browsing"""
    # TechVault electronics demo data
    products = [
        {'id': 1, 'name': 'iPhone 15 Pro Max', 'price': 1199.99, 'description': 'Latest iPhone with titanium design, A17 Pro chip, and advanced camera system'},
        {'id': 2, 'name': 'MacBook Pro 16"', 'price': 2499.99, 'description': 'M3 Max chip, 36GB unified memory, 1TB SSD - Perfect for professionals'},
        {'id': 3, 'name': 'PlayStation 5', 'price': 499.99, 'description': 'Next-gen gaming console with ultra-high speed SSD and 3D audio'},
        {'id': 4, 'name': 'Samsung Galaxy S24 Ultra', 'price': 1299.99, 'description': 'AI-powered smartphone with S Pen, 200MP camera, and titanium build'},
        {'id': 5, 'name': 'iPad Pro 12.9"', 'price': 1099.99, 'description': 'M2 chip, Liquid Retina XDR display, and Apple Pencil compatibility'},
        {'id': 6, 'name': 'AirPods Pro (3rd Gen)', 'price': 249.99, 'description': 'Active noise cancellation, spatial audio, and USB-C charging'},
        {'id': 7, 'name': 'Dell XPS 13', 'price': 999.99, 'description': 'Ultra-portable laptop with Intel Core i7, 16GB RAM, and InfinityEdge display'},
        {'id': 8, 'name': 'Nintendo Switch OLED', 'price': 349.99, 'description': 'Vibrant OLED screen, enhanced audio, and versatile gaming modes'}
    ]
    return jsonify({
        'products': products,
        'total': len(products)
    })

@products_bp.route('/<int:product_id>', methods=['GET'])
@jwt_required()
def get_product(product_id):
    """Get a specific product"""
    # Mock data
    product = {
        'id': product_id,
        'name': f'Product {product_id}',
        'price': 99.99 + (product_id * 10),
        'description': f'Sample product {product_id}'
    }
    return jsonify(product)

@products_bp.route('/', methods=['POST'])
@jwt_required()
def create_product():
    """Create a new product"""
    data = request.get_json()
    
    if not data or 'name' not in data:
        return jsonify({'error': 'Product name is required'}), 400
    
    # Mock creation
    product = {
        'id': 999,  # Mock ID
        'name': data['name'],
        'price': data.get('price', 0.0),
        'description': data.get('description', ''),
        'created_by': get_jwt_identity()
    }
    
    return jsonify(product), 201
