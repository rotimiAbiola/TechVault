from flask import Flask, request, jsonify
from flask_sqlalchemy import SQLAlchemy
from flask_jwt_extended import JWTManager, jwt_required, get_jwt_identity
from marshmallow import Schema, fields, ValidationError
import os
import uuid
from datetime import datetime
from decimal import Decimal

app = Flask(__name__)

# Configuration
app.config['SQLALCHEMY_DATABASE_URI'] = os.getenv('DATABASE_URL', 'postgresql://postgres:postgres@postgres:5432/paymentdb')
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
app.config['JWT_SECRET_KEY'] = os.getenv('JWT_SECRET_KEY', 'payment-jwt-secret-change-in-production')

# Initialize extensions
db = SQLAlchemy(app)
jwt = JWTManager(app)

# Payment models
class Payment(db.Model):
    __tablename__ = 'payments'
    
    id = db.Column(db.Integer, primary_key=True)
    payment_id = db.Column(db.String(100), unique=True, nullable=False)
    user_id = db.Column(db.Integer, nullable=False)
    amount = db.Column(db.Numeric(10, 2), nullable=False)
    currency = db.Column(db.String(3), default='USD')
    status = db.Column(db.String(20), default='pending')  # pending, processing, completed, failed, refunded
    payment_method = db.Column(db.String(50))  # card, paypal, bank_transfer
    payment_intent_id = db.Column(db.String(255))  # Stripe payment intent ID
    transaction_id = db.Column(db.String(255))  # External payment processor transaction ID
    created_at = db.Column(db.DateTime, default=db.func.current_timestamp())
    updated_at = db.Column(db.DateTime, default=db.func.current_timestamp(), onupdate=db.func.current_timestamp())
    
    def to_dict(self):
        return {
            'id': self.id,
            'payment_id': self.payment_id,
            'user_id': self.user_id,
            'amount': float(self.amount),
            'currency': self.currency,
            'status': self.status,
            'payment_method': self.payment_method,
            'payment_intent_id': self.payment_intent_id,
            'transaction_id': self.transaction_id,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None
        }

class PaymentSchema(Schema):
    amount = fields.Decimal(required=True, places=2, validate=lambda x: x > 0)
    currency = fields.Str(missing='USD')
    payment_method = fields.Str(required=True)

class PaymentIntentSchema(Schema):
    amount = fields.Decimal(required=True, places=2, validate=lambda x: x > 0)
    currency = fields.Str(missing='USD')

def generate_payment_id():
    """Generate unique payment ID"""
    return f"pay_{uuid.uuid4().hex[:16]}"

@app.route('/api/payment/create-intent', methods=['POST'])
@jwt_required()
def create_payment_intent():
    """Create payment intent (Stripe-like flow)"""
    try:
        schema = PaymentIntentSchema()
        data = schema.load(request.json)
        user_id = get_jwt_identity()
        
        # Generate payment intent
        payment_id = generate_payment_id()
        payment_intent_id = f"pi_{uuid.uuid4().hex[:24]}"
        
        # Create payment record
        payment = Payment(
            payment_id=payment_id,
            user_id=user_id,
            amount=data['amount'],
            currency=data['currency'],
            status='pending',
            payment_intent_id=payment_intent_id
        )
        
        db.session.add(payment)
        db.session.commit()
        
        # In real implementation, you would create actual Stripe payment intent here
        client_secret = f"{payment_intent_id}_secret_{uuid.uuid4().hex[:16]}"
        
        return jsonify({
            'payment_intent': {
                'id': payment_intent_id,
                'client_secret': client_secret,
                'amount': float(data['amount']),
                'currency': data['currency'],
                'status': 'requires_payment_method'
            },
            'payment_id': payment_id
        }), 201
        
    except ValidationError as e:
        return jsonify({'error': e.messages}), 400
    except Exception as e:
        return jsonify({'error': 'Failed to create payment intent'}), 500

@app.route('/api/payment/process', methods=['POST'])
@jwt_required()
def process_payment():
    """Process payment (simulated)"""
    try:
        schema = PaymentSchema()
        data = schema.load(request.json)
        user_id = get_jwt_identity()
        
        payment_intent_id = request.json.get('payment_intent_id')
        
        if not payment_intent_id:
            return jsonify({'error': 'Payment intent ID required'}), 400
        
        # Find payment by intent ID
        payment = Payment.query.filter_by(
            payment_intent_id=payment_intent_id,
            user_id=user_id
        ).first()
        
        if not payment:
            return jsonify({'error': 'Payment not found'}), 404
        
        if payment.status != 'pending':
            return jsonify({'error': f'Payment already {payment.status}'}), 400
        
        # Update payment details
        payment.payment_method = data['payment_method']
        payment.status = 'processing'
        
        # Simulate payment processing
        import random
        success_rate = 0.9  # 90% success rate for demo
        
        if random.random() < success_rate:
            payment.status = 'completed'
            payment.transaction_id = f"txn_{uuid.uuid4().hex[:20]}"
            message = 'Payment processed successfully'
        else:
            payment.status = 'failed'
            message = 'Payment failed. Please try again.'
        
        db.session.commit()
        
        return jsonify({
            'message': message,
            'payment': payment.to_dict()
        }), 200
        
    except ValidationError as e:
        return jsonify({'error': e.messages}), 400
    except Exception as e:
        return jsonify({'error': 'Failed to process payment'}), 500

@app.route('/api/payment/<payment_id>', methods=['GET'])
@jwt_required()
def get_payment(payment_id):
    """Get payment details"""
    try:
        user_id = get_jwt_identity()
        
        payment = Payment.query.filter_by(
            payment_id=payment_id,
            user_id=user_id
        ).first()
        
        if not payment:
            return jsonify({'error': 'Payment not found'}), 404
        
        return jsonify(payment.to_dict()), 200
        
    except Exception as e:
        return jsonify({'error': 'Failed to fetch payment'}), 500

@app.route('/api/payment/user/history', methods=['GET'])
@jwt_required()
def get_payment_history():
    """Get user's payment history"""
    try:
        user_id = get_jwt_identity()
        page = request.args.get('page', 1, type=int)
        per_page = min(request.args.get('per_page', 20, type=int), 100)
        
        payments = Payment.query.filter_by(user_id=user_id).order_by(
            Payment.created_at.desc()
        ).paginate(
            page=page,
            per_page=per_page,
            error_out=False
        )
        
        return jsonify({
            'payments': [payment.to_dict() for payment in payments.items],
            'total': payments.total,
            'pages': payments.pages,
            'current_page': page,
            'per_page': per_page
        }), 200
        
    except Exception as e:
        return jsonify({'error': 'Failed to fetch payment history'}), 500

@app.route('/api/payment/<payment_id>/refund', methods=['POST'])
@jwt_required()
def refund_payment(payment_id):
    """Refund payment"""
    try:
        user_id = get_jwt_identity()
        
        payment = Payment.query.filter_by(
            payment_id=payment_id,
            user_id=user_id
        ).first()
        
        if not payment:
            return jsonify({'error': 'Payment not found'}), 404
        
        if payment.status != 'completed':
            return jsonify({'error': 'Only completed payments can be refunded'}), 400
        
        # Process refund (simulated)
        payment.status = 'refunded'
        db.session.commit()
        
        return jsonify({
            'message': 'Payment refunded successfully',
            'payment': payment.to_dict()
        }), 200
        
    except Exception as e:
        return jsonify({'error': 'Failed to process refund'}), 500

@app.route('/api/payment/webhook', methods=['POST'])
def payment_webhook():
    """Payment webhook for external payment processors"""
    try:
        # This would handle webhooks from Stripe, PayPal, etc.
        data = request.json
        
        # Verify webhook signature (implementation depends on payment processor)
        # For demo purposes, we'll skip verification
        
        payment_intent_id = data.get('payment_intent_id')
        status = data.get('status')
        
        if payment_intent_id and status:
            payment = Payment.query.filter_by(payment_intent_id=payment_intent_id).first()
            if payment:
                payment.status = status
                if status == 'completed':
                    payment.transaction_id = data.get('transaction_id', f"txn_{uuid.uuid4().hex[:20]}")
                db.session.commit()
        
        return jsonify({'received': True}), 200
        
    except Exception as e:
        return jsonify({'error': 'Webhook processing failed'}), 500

@app.route('/health')
def health():
    """Health check endpoint"""
    try:
        # Test database connection
        db.session.execute(db.text('SELECT 1'))
        return jsonify({'status': 'healthy', 'service': 'payment-service'}), 200
    except Exception as e:
        return jsonify({'status': 'unhealthy', 'service': 'payment-service', 'error': str(e)}), 503

# Create tables
with app.app_context():
    db.create_all()

if __name__ == '__main__':
    port = int(os.getenv('PORT', 5004))
    app.run(host='0.0.0.0', port=port, debug=False)
