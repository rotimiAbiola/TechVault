from flask import Flask, request, jsonify
from flask_sqlalchemy import SQLAlchemy
from flask_jwt_extended import JWTManager, jwt_required, get_jwt_identity
from marshmallow import Schema, fields, ValidationError
import os
import uuid
import requests
from datetime import datetime
from decimal import Decimal

app = Flask(__name__)

# Configuration
app.config['SQLALCHEMY_DATABASE_URI'] = os.getenv('DATABASE_URL', 'postgresql://postgres:postgres@postgres:5432/orderdb')
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
app.config['JWT_SECRET_KEY'] = os.getenv('JWT_SECRET_KEY', 'order-jwt-secret-change-in-production')

# Service URLs
CART_SERVICE_URL = os.getenv('CART_SERVICE_URL', 'http://cart-service:5003')
PAYMENT_SERVICE_URL = os.getenv('PAYMENT_SERVICE_URL', 'http://payment-service:5004')

# Initialize extensions
db = SQLAlchemy(app)
jwt = JWTManager(app)

# Order models
class Order(db.Model):
    __tablename__ = 'orders'
    
    id = db.Column(db.Integer, primary_key=True)
    order_number = db.Column(db.String(100), unique=True, nullable=False)
    user_id = db.Column(db.Integer, nullable=False)
    status = db.Column(db.String(20), default='pending')  # pending, confirmed, processing, shipped, delivered, cancelled
    total_amount = db.Column(db.Numeric(10, 2), nullable=False)
    payment_id = db.Column(db.String(100))
    shipping_address = db.Column(db.JSON)
    billing_address = db.Column(db.JSON)
    notes = db.Column(db.Text)
    created_at = db.Column(db.DateTime, default=db.func.current_timestamp())
    updated_at = db.Column(db.DateTime, default=db.func.current_timestamp(), onupdate=db.func.current_timestamp())
    shipped_at = db.Column(db.DateTime)
    delivered_at = db.Column(db.DateTime)
    
    items = db.relationship('OrderItem', backref='order', lazy=True, cascade='all, delete-orphan')
    
    def to_dict(self):
        return {
            'id': self.id,
            'order_number': self.order_number,
            'user_id': self.user_id,
            'status': self.status,
            'total_amount': float(self.total_amount),
            'payment_id': self.payment_id,
            'shipping_address': self.shipping_address,
            'billing_address': self.billing_address,
            'notes': self.notes,
            'items': [item.to_dict() for item in self.items],
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None,
            'shipped_at': self.shipped_at.isoformat() if self.shipped_at else None,
            'delivered_at': self.delivered_at.isoformat() if self.delivered_at else None
        }

class OrderItem(db.Model):
    __tablename__ = 'order_items'
    
    id = db.Column(db.Integer, primary_key=True)
    order_id = db.Column(db.Integer, db.ForeignKey('orders.id'), nullable=False)
    product_id = db.Column(db.Integer, nullable=False)
    product_name = db.Column(db.String(255), nullable=False)
    price = db.Column(db.Numeric(10, 2), nullable=False)
    quantity = db.Column(db.Integer, nullable=False)
    product_image_url = db.Column(db.String(500))
    
    def to_dict(self):
        return {
            'id': self.id,
            'product_id': self.product_id,
            'product_name': self.product_name,
            'price': float(self.price),
            'quantity': self.quantity,
            'product_image_url': self.product_image_url,
            'subtotal': float(self.quantity * self.price)
        }

class OrderSchema(Schema):
    shipping_address = fields.Dict(required=True)
    billing_address = fields.Dict()
    notes = fields.Str()
    payment_method = fields.Str(required=True)

class AddressSchema(Schema):
    first_name = fields.Str(required=True)
    last_name = fields.Str(required=True)
    address_line_1 = fields.Str(required=True)
    address_line_2 = fields.Str()
    city = fields.Str(required=True)
    state = fields.Str(required=True)
    postal_code = fields.Str(required=True)
    country = fields.Str(required=True)
    phone = fields.Str()

def generate_order_number():
    """Generate unique order number"""
    return f"ORD-{datetime.now().strftime('%Y%m%d')}-{uuid.uuid4().hex[:8].upper()}"

def get_cart_items(user_id, headers):
    """Get cart items from cart service"""
    try:
        response = requests.get(
            f"{CART_SERVICE_URL}/api/cart",
            headers=headers,
            timeout=10
        )
        
        if response.status_code == 200:
            return response.json()
        else:
            return None
    except Exception as e:
        print(f"Error fetching cart: {e}")
        return None

def clear_cart(user_id, headers):
    """Clear cart after successful order"""
    try:
        response = requests.delete(
            f"{CART_SERVICE_URL}/api/cart/clear",
            headers=headers,
            timeout=10
        )
        return response.status_code == 200
    except Exception as e:
        print(f"Error clearing cart: {e}")
        return False

def create_payment_intent(amount, currency='USD', headers=None):
    """Create payment intent via payment service"""
    try:
        response = requests.post(
            f"{PAYMENT_SERVICE_URL}/api/payment/create-intent",
            json={'amount': float(amount), 'currency': currency},
            headers=headers,
            timeout=10
        )
        
        if response.status_code == 201:
            return response.json()
        else:
            return None
    except Exception as e:
        print(f"Error creating payment intent: {e}")
        return None

@app.route('/api/orders', methods=['POST'])
@jwt_required()
def create_order():
    """Create new order"""
    try:
        schema = OrderSchema()
        data = schema.load(request.json)
        user_id = get_jwt_identity()
        
        # Get user's cart
        headers = {'Authorization': request.headers.get('Authorization')}
        cart_data = get_cart_items(user_id, headers)
        
        if not cart_data or not cart_data.get('items'):
            return jsonify({'error': 'Cart is empty'}), 400
        
        total_amount = cart_data['total_amount']
        
        # Create payment intent
        payment_response = create_payment_intent(total_amount, headers=headers)
        if not payment_response:
            return jsonify({'error': 'Failed to initialize payment'}), 500
        
        # Create order
        order = Order(
            order_number=generate_order_number(),
            user_id=user_id,
            total_amount=total_amount,
            payment_id=payment_response.get('payment_id'),
            shipping_address=data['shipping_address'],
            billing_address=data.get('billing_address', data['shipping_address']),
            notes=data.get('notes')
        )
        
        db.session.add(order)
        db.session.flush()  # Get order ID
        
        # Create order items from cart
        for cart_item in cart_data['items']:
            order_item = OrderItem(
                order_id=order.id,
                product_id=cart_item['product_id'],
                product_name=cart_item['product_name'],
                price=cart_item['price'],
                quantity=cart_item['quantity'],
                product_image_url=cart_item.get('product_image_url')
            )
            db.session.add(order_item)
        
        db.session.commit()
        
        return jsonify({
            'message': 'Order created successfully',
            'order': order.to_dict(),
            'payment_intent': payment_response['payment_intent']
        }), 201
        
    except ValidationError as e:
        return jsonify({'error': e.messages}), 400
    except Exception as e:
        return jsonify({'error': 'Failed to create order'}), 500

@app.route('/api/orders/<order_number>/confirm', methods=['POST'])
@jwt_required()
def confirm_order(order_number):
    """Confirm order after successful payment"""
    try:
        user_id = get_jwt_identity()
        
        order = Order.query.filter_by(
            order_number=order_number,
            user_id=user_id
        ).first()
        
        if not order:
            return jsonify({'error': 'Order not found'}), 404
        
        if order.status != 'pending':
            return jsonify({'error': f'Order is already {order.status}'}), 400
        
        # Update order status
        order.status = 'confirmed'
        db.session.commit()
        
        # Clear user's cart
        headers = {'Authorization': request.headers.get('Authorization')}
        clear_cart(user_id, headers)
        
        return jsonify({
            'message': 'Order confirmed successfully',
            'order': order.to_dict()
        }), 200
        
    except Exception as e:
        return jsonify({'error': 'Failed to confirm order'}), 500

@app.route('/api/orders', methods=['GET'])
@jwt_required()
def get_orders():
    """Get user's orders"""
    try:
        user_id = get_jwt_identity()
        page = request.args.get('page', 1, type=int)
        per_page = min(request.args.get('per_page', 20, type=int), 100)
        status = request.args.get('status')
        
        query = Order.query.filter_by(user_id=user_id)
        
        if status:
            query = query.filter_by(status=status)
        
        orders = query.order_by(Order.created_at.desc()).paginate(
            page=page,
            per_page=per_page,
            error_out=False
        )
        
        return jsonify({
            'orders': [order.to_dict() for order in orders.items],
            'total': orders.total,
            'pages': orders.pages,
            'current_page': page,
            'per_page': per_page
        }), 200
        
    except Exception as e:
        return jsonify({'error': 'Failed to fetch orders'}), 500

@app.route('/api/orders/<order_number>', methods=['GET'])
@jwt_required()
def get_order(order_number):
    """Get specific order"""
    try:
        user_id = get_jwt_identity()
        
        order = Order.query.filter_by(
            order_number=order_number,
            user_id=user_id
        ).first()
        
        if not order:
            return jsonify({'error': 'Order not found'}), 404
        
        return jsonify(order.to_dict()), 200
        
    except Exception as e:
        return jsonify({'error': 'Failed to fetch order'}), 500

@app.route('/api/orders/<order_number>/cancel', methods=['POST'])
@jwt_required()
def cancel_order(order_number):
    """Cancel order"""
    try:
        user_id = get_jwt_identity()
        
        order = Order.query.filter_by(
            order_number=order_number,
            user_id=user_id
        ).first()
        
        if not order:
            return jsonify({'error': 'Order not found'}), 404
        
        if order.status not in ['pending', 'confirmed']:
            return jsonify({'error': 'Order cannot be cancelled'}), 400
        
        order.status = 'cancelled'
        db.session.commit()
        
        return jsonify({
            'message': 'Order cancelled successfully',
            'order': order.to_dict()
        }), 200
        
    except Exception as e:
        return jsonify({'error': 'Failed to cancel order'}), 500

@app.route('/api/orders/<order_number>/status', methods=['PUT'])
@jwt_required()
def update_order_status(order_number):
    """Update order status (admin function)"""
    try:
        data = request.json
        new_status = data.get('status')
        
        if not new_status:
            return jsonify({'error': 'Status is required'}), 400
        
        valid_statuses = ['pending', 'confirmed', 'processing', 'shipped', 'delivered', 'cancelled']
        if new_status not in valid_statuses:
            return jsonify({'error': 'Invalid status'}), 400
        
        order = Order.query.filter_by(order_number=order_number).first()
        
        if not order:
            return jsonify({'error': 'Order not found'}), 404
        
        order.status = new_status
        
        if new_status == 'shipped':
            order.shipped_at = datetime.utcnow()
        elif new_status == 'delivered':
            order.delivered_at = datetime.utcnow()
        
        db.session.commit()
        
        return jsonify({
            'message': f'Order status updated to {new_status}',
            'order': order.to_dict()
        }), 200
        
    except Exception as e:
        return jsonify({'error': 'Failed to update order status'}), 500

@app.route('/health')
def health():
    """Health check endpoint"""
    try:
        # Test database connection
        db.session.execute(db.text('SELECT 1'))
        return jsonify({'status': 'healthy', 'service': 'order-service'}), 200
    except Exception as e:
        return jsonify({'status': 'unhealthy', 'service': 'order-service', 'error': str(e)}), 503

# Create tables
with app.app_context():
    db.create_all()

if __name__ == '__main__':
    port = int(os.getenv('PORT', 5005))
    app.run(host='0.0.0.0', port=port, debug=False)
