from flask import Flask, request, jsonify
from flask_sqlalchemy import SQLAlchemy
from marshmallow import Schema, fields, ValidationError
import os

app = Flask(__name__)

# Configuration
app.config['SQLALCHEMY_DATABASE_URI'] = os.getenv('DATABASE_URL', 'postgresql://postgres:postgres@postgres:5432/productdb')
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

# Initialize extensions
db = SQLAlchemy(app)

# Product model
class Product(db.Model):
    __tablename__ = 'products'
    
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(255), nullable=False)
    description = db.Column(db.Text)
    price = db.Column(db.Numeric(10, 2), nullable=False)
    category = db.Column(db.String(100))
    brand = db.Column(db.String(100))
    stock_quantity = db.Column(db.Integer, default=0)
    image_url = db.Column(db.String(500))
    is_active = db.Column(db.Boolean, default=True)
    created_at = db.Column(db.DateTime, default=db.func.current_timestamp())
    updated_at = db.Column(db.DateTime, default=db.func.current_timestamp(), onupdate=db.func.current_timestamp())
    
    def to_dict(self):
        return {
            'id': self.id,
            'name': self.name,
            'description': self.description,
            'price': float(self.price),
            'category': self.category,
            'brand': self.brand,
            'stock_quantity': self.stock_quantity,
            'image_url': self.image_url,
            'is_active': self.is_active,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None
        }

class ProductSchema(Schema):
    name = fields.Str(required=True)
    description = fields.Str()
    price = fields.Decimal(required=True, places=2)
    category = fields.Str()
    brand = fields.Str()
    stock_quantity = fields.Int()
    image_url = fields.Str()

def initialize_demo_products():
    """Initialize TechVault demo products"""
    if Product.query.count() == 0:
        demo_products = [
            {
                'name': 'iPhone 15 Pro Max',
                'description': 'Latest iPhone with titanium design, A17 Pro chip, and advanced camera system',
                'price': 1199.99,
                'category': 'Smartphones',
                'brand': 'Apple',
                'stock_quantity': 50,
                'image_url': '/images/iphone-15-pro-max.jpg'
            },
            {
                'name': 'MacBook Pro 16"',
                'description': 'M3 Max chip, 36GB unified memory, 1TB SSD - Perfect for professionals',
                'price': 2499.99,
                'category': 'Laptops',
                'brand': 'Apple',
                'stock_quantity': 25,
                'image_url': '/images/macbook-pro-16.jpg'
            },
            {
                'name': 'PlayStation 5',
                'description': 'Next-gen gaming console with ultra-high speed SSD and 3D audio',
                'price': 499.99,
                'category': 'Gaming',
                'brand': 'Sony',
                'stock_quantity': 30,
                'image_url': '/images/ps5.jpg'
            },
            {
                'name': 'Samsung Galaxy S24 Ultra',
                'description': 'AI-powered smartphone with S Pen, 200MP camera, and titanium build',
                'price': 1299.99,
                'category': 'Smartphones',
                'brand': 'Samsung',
                'stock_quantity': 40,
                'image_url': '/images/galaxy-s24-ultra.jpg'
            },
            {
                'name': 'iPad Pro 12.9"',
                'description': 'M2 chip, Liquid Retina XDR display, and Apple Pencil compatibility',
                'price': 1099.99,
                'category': 'Tablets',
                'brand': 'Apple',
                'stock_quantity': 35,
                'image_url': '/images/ipad-pro-12.jpg'
            },
            {
                'name': 'AirPods Pro (3rd Gen)',
                'description': 'Active noise cancellation, spatial audio, and USB-C charging',
                'price': 249.99,
                'category': 'Audio',
                'brand': 'Apple',
                'stock_quantity': 100,
                'image_url': '/images/airpods-pro-3.jpg'
            },
            {
                'name': 'Dell XPS 13',
                'description': 'Ultra-portable laptop with Intel Core i7, 16GB RAM, and InfinityEdge display',
                'price': 999.99,
                'category': 'Laptops',
                'brand': 'Dell',
                'stock_quantity': 20,
                'image_url': '/images/dell-xps-13.jpg'
            },
            {
                'name': 'Nintendo Switch OLED',
                'description': 'Vibrant OLED screen, enhanced audio, and versatile gaming modes',
                'price': 349.99,
                'category': 'Gaming',
                'brand': 'Nintendo',
                'stock_quantity': 45,
                'image_url': '/images/nintendo-switch-oled.jpg'
            }
        ]
        
        for product_data in demo_products:
            product = Product(**product_data)
            db.session.add(product)
        
        try:
            db.session.commit()
            print("Demo products initialized successfully")
        except Exception as e:
            db.session.rollback()
            print(f"Error initializing demo products: {e}")

@app.route('/api/products', methods=['GET'])
def get_products():
    """Get all products (public access)"""
    try:
        # Get query parameters
        page = request.args.get('page', 1, type=int)
        per_page = min(request.args.get('per_page', 20, type=int), 100)
        category = request.args.get('category')
        brand = request.args.get('brand')
        search = request.args.get('search')
        
        # Build query
        query = Product.query.filter_by(is_active=True)
        
        if category:
            query = query.filter(Product.category.ilike(f'%{category}%'))
        
        if brand:
            query = query.filter(Product.brand.ilike(f'%{brand}%'))
        
        if search:
            query = query.filter(
                db.or_(
                    Product.name.ilike(f'%{search}%'),
                    Product.description.ilike(f'%{search}%')
                )
            )
        
        # Execute query with pagination
        products = query.paginate(
            page=page,
            per_page=per_page,
            error_out=False
        )
        
        return jsonify({
            'products': [product.to_dict() for product in products.items],
            'total': products.total,
            'pages': products.pages,
            'current_page': page,
            'per_page': per_page
        }), 200
        
    except Exception as e:
        return jsonify({'error': 'Failed to fetch products'}), 500

@app.route('/api/products/<int:product_id>', methods=['GET'])
def get_product(product_id):
    """Get a specific product"""
    try:
        product = Product.query.filter_by(id=product_id, is_active=True).first()
        
        if not product:
            return jsonify({'error': 'Product not found'}), 404
        
        return jsonify(product.to_dict()), 200
        
    except Exception as e:
        return jsonify({'error': 'Failed to fetch product'}), 500

@app.route('/api/products/categories', methods=['GET'])
def get_categories():
    """Get all product categories"""
    try:
        categories = db.session.query(Product.category).distinct().filter(
            Product.is_active == True,
            Product.category.isnot(None)
        ).all()
        
        return jsonify({
            'categories': [cat[0] for cat in categories]
        }), 200
        
    except Exception as e:
        return jsonify({'error': 'Failed to fetch categories'}), 500

@app.route('/api/products/brands', methods=['GET'])
def get_brands():
    """Get all product brands"""
    try:
        brands = db.session.query(Product.brand).distinct().filter(
            Product.is_active == True,
            Product.brand.isnot(None)
        ).all()
        
        return jsonify({
            'brands': [brand[0] for brand in brands]
        }), 200
        
    except Exception as e:
        return jsonify({'error': 'Failed to fetch brands'}), 500

@app.route('/health')
def health():
    """Health check endpoint"""
    try:
        # Test database connection
        db.session.execute(db.text('SELECT 1'))
        return jsonify({'status': 'healthy', 'service': 'product-service'}), 200
    except Exception as e:
        return jsonify({'status': 'unhealthy', 'service': 'product-service', 'error': str(e)}), 503

# Create tables and initialize demo data
with app.app_context():
    db.create_all()
    initialize_demo_products()

if __name__ == '__main__':
    port = int(os.getenv('PORT', 5002))
    app.run(host='0.0.0.0', port=port, debug=False)
