from flask import Flask, request, jsonify, session
from flask_sqlalchemy import SQLAlchemy
from flask_session import Session
from marshmallow import Schema, fields, ValidationError
import redis
import json
import os
from datetime import datetime, timedelta

app = Flask(__name__)

# Configuration
app.config['SQLALCHEMY_DATABASE_URI'] = os.getenv('DATABASE_URL', 'postgresql://postgres:postgres@postgres:5432/cartdb')
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
app.config['SECRET_KEY'] = os.getenv('SECRET_KEY', 'cart-secret-key-change-in-production')

# Redis configuration for sessions
app.config['SESSION_TYPE'] = 'redis'
app.config['SESSION_REDIS'] = redis.from_url(os.getenv('REDIS_URL', 'redis://redis:6379'))
app.config['SESSION_PERMANENT'] = False
app.config['SESSION_USE_SIGNER'] = True
app.config['SESSION_KEY_PREFIX'] = 'cart:'

# Initialize extensions
db = SQLAlchemy(app)
Session(app)

# Cart models
class Cart(db.Model):
    __tablename__ = 'carts'
    
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, nullable=True)  # Nullable for guest carts
    session_id = db.Column(db.String(255), nullable=True)  # For guest users
    created_at = db.Column(db.DateTime, default=db.func.current_timestamp())
    updated_at = db.Column(db.DateTime, default=db.func.current_timestamp(), onupdate=db.func.current_timestamp())
    
    items = db.relationship('CartItem', backref='cart', lazy=True, cascade='all, delete-orphan')
    
    def to_dict(self):
        return {
            'id': self.id,
            'user_id': self.user_id,
            'session_id': self.session_id,
            'items': [item.to_dict() for item in self.items],
            'total_items': sum(item.quantity for item in self.items),
            'total_amount': float(sum(item.quantity * item.price for item in self.items)),
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None
        }

class CartItem(db.Model):
    __tablename__ = 'cart_items'
    
    id = db.Column(db.Integer, primary_key=True)
    cart_id = db.Column(db.Integer, db.ForeignKey('carts.id'), nullable=False)
    product_id = db.Column(db.Integer, nullable=False)
    product_name = db.Column(db.String(255), nullable=False)
    price = db.Column(db.Numeric(10, 2), nullable=False)
    quantity = db.Column(db.Integer, nullable=False, default=1)
    product_image_url = db.Column(db.String(500))
    added_at = db.Column(db.DateTime, default=db.func.current_timestamp())
    
    def to_dict(self):
        return {
            'id': self.id,
            'product_id': self.product_id,
            'product_name': self.product_name,
            'price': float(self.price),
            'quantity': self.quantity,
            'product_image_url': self.product_image_url,
            'subtotal': float(self.quantity * self.price),
            'added_at': self.added_at.isoformat() if self.added_at else None
        }

class CartItemSchema(Schema):
    product_id = fields.Int(required=True)
    product_name = fields.Str(required=True)
    price = fields.Decimal(required=True, places=2)
    quantity = fields.Int(required=True, validate=lambda x: x > 0)
    product_image_url = fields.Str()

def get_or_create_cart():
    """Get or create cart for current session/user"""
    user_id = request.headers.get('X-User-ID')  # From JWT token if authenticated
    
    if user_id:
        # Authenticated user
        cart = Cart.query.filter_by(user_id=int(user_id)).first()
        if not cart:
            cart = Cart(user_id=int(user_id))
            db.session.add(cart)
            db.session.commit()
    else:
        # Guest user - use session
        if 'cart_id' not in session:
            cart = Cart(session_id=session.get('session_id', session.sid))
            db.session.add(cart)
            db.session.commit()
            session['cart_id'] = cart.id
        else:
            cart = Cart.query.get(session['cart_id'])
            if not cart:
                cart = Cart(session_id=session.get('session_id', session.sid))
                db.session.add(cart)
                db.session.commit()
                session['cart_id'] = cart.id
    
    return cart

@app.route('/api/cart', methods=['GET'])
def get_cart():
    """Get current user's cart"""
    try:
        cart = get_or_create_cart()
        return jsonify(cart.to_dict()), 200
        
    except Exception as e:
        return jsonify({'error': 'Failed to fetch cart'}), 500

@app.route('/api/cart/items', methods=['POST'])
def add_item():
    """Add item to cart"""
    try:
        schema = CartItemSchema()
        data = schema.load(request.json)
        
        cart = get_or_create_cart()
        
        # Check if item already exists in cart
        existing_item = CartItem.query.filter_by(
            cart_id=cart.id,
            product_id=data['product_id']
        ).first()
        
        if existing_item:
            # Update quantity
            existing_item.quantity += data['quantity']
        else:
            # Add new item
            new_item = CartItem(
                cart_id=cart.id,
                product_id=data['product_id'],
                product_name=data['product_name'],
                price=data['price'],
                quantity=data['quantity'],
                product_image_url=data.get('product_image_url')
            )
            db.session.add(new_item)
        
        db.session.commit()
        
        return jsonify({
            'message': 'Item added to cart successfully',
            'cart': cart.to_dict()
        }), 201
        
    except ValidationError as e:
        return jsonify({'error': e.messages}), 400
    except Exception as e:
        return jsonify({'error': 'Failed to add item to cart'}), 500

@app.route('/api/cart/items/<int:item_id>', methods=['PUT'])
def update_item(item_id):
    """Update cart item quantity"""
    try:
        data = request.json
        quantity = data.get('quantity')
        
        if not quantity or quantity <= 0:
            return jsonify({'error': 'Invalid quantity'}), 400
        
        cart = get_or_create_cart()
        item = CartItem.query.filter_by(id=item_id, cart_id=cart.id).first()
        
        if not item:
            return jsonify({'error': 'Item not found in cart'}), 404
        
        item.quantity = quantity
        db.session.commit()
        
        return jsonify({
            'message': 'Item updated successfully',
            'cart': cart.to_dict()
        }), 200
        
    except Exception as e:
        return jsonify({'error': 'Failed to update item'}), 500

@app.route('/api/cart/items/<int:item_id>', methods=['DELETE'])
def remove_item(item_id):
    """Remove item from cart"""
    try:
        cart = get_or_create_cart()
        item = CartItem.query.filter_by(id=item_id, cart_id=cart.id).first()
        
        if not item:
            return jsonify({'error': 'Item not found in cart'}), 404
        
        db.session.delete(item)
        db.session.commit()
        
        return jsonify({
            'message': 'Item removed from cart successfully',
            'cart': cart.to_dict()
        }), 200
        
    except Exception as e:
        return jsonify({'error': 'Failed to remove item'}), 500

@app.route('/api/cart/clear', methods=['DELETE'])
def clear_cart():
    """Clear all items from cart"""
    try:
        cart = get_or_create_cart()
        
        # Delete all items
        CartItem.query.filter_by(cart_id=cart.id).delete()
        db.session.commit()
        
        return jsonify({
            'message': 'Cart cleared successfully',
            'cart': cart.to_dict()
        }), 200
        
    except Exception as e:
        return jsonify({'error': 'Failed to clear cart'}), 500

@app.route('/api/cart/merge', methods=['POST'])
def merge_carts():
    """Merge guest cart with user cart after login"""
    try:
        data = request.json
        user_id = data.get('user_id')
        guest_cart_id = data.get('guest_cart_id')
        
        if not user_id or not guest_cart_id:
            return jsonify({'error': 'Missing user_id or guest_cart_id'}), 400
        
        # Get or create user cart
        user_cart = Cart.query.filter_by(user_id=user_id).first()
        if not user_cart:
            user_cart = Cart(user_id=user_id)
            db.session.add(user_cart)
            db.session.commit()
        
        # Get guest cart
        guest_cart = Cart.query.get(guest_cart_id)
        if not guest_cart:
            return jsonify({'error': 'Guest cart not found'}), 404
        
        # Merge items
        for guest_item in guest_cart.items:
            existing_item = CartItem.query.filter_by(
                cart_id=user_cart.id,
                product_id=guest_item.product_id
            ).first()
            
            if existing_item:
                existing_item.quantity += guest_item.quantity
            else:
                new_item = CartItem(
                    cart_id=user_cart.id,
                    product_id=guest_item.product_id,
                    product_name=guest_item.product_name,
                    price=guest_item.price,
                    quantity=guest_item.quantity,
                    product_image_url=guest_item.product_image_url
                )
                db.session.add(new_item)
        
        # Delete guest cart
        db.session.delete(guest_cart)
        db.session.commit()
        
        return jsonify({
            'message': 'Carts merged successfully',
            'cart': user_cart.to_dict()
        }), 200
        
    except Exception as e:
        return jsonify({'error': 'Failed to merge carts'}), 500

@app.route('/health')
def health():
    """Health check endpoint"""
    try:
        # Test database connection
        db.session.execute(db.text('SELECT 1'))
        # Test Redis connection
        app.config['SESSION_REDIS'].ping()
        return jsonify({'status': 'healthy', 'service': 'cart-service'}), 200
    except Exception as e:
        return jsonify({'status': 'unhealthy', 'service': 'cart-service', 'error': str(e)}), 503

# Create tables
with app.app_context():
    db.create_all()

if __name__ == '__main__':
    port = int(os.getenv('PORT', 5003))
    app.run(host='0.0.0.0', port=port, debug=False)
