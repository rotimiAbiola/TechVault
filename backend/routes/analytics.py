from flask import Blueprint, jsonify, request
from flask_jwt_extended import jwt_required
import random
from datetime import datetime, timedelta

analytics_bp = Blueprint('analytics', __name__)

@analytics_bp.route('/dashboard', methods=['GET'])
@jwt_required()
def get_dashboard_data():
    """Get dashboard analytics data"""
    # TechVault business analytics - realistic demo data
    data = {
        'sales': {
            'total': 2750000,  # $2.75M total sales
            'this_month': 485000,  # $485K this month
            'growth': 12.5  # 12.5% growth
        },
        'users': {
            'total': 15420,  # Total registered users
            'active': 8930,  # Active users this month
            'new': 1250  # New users this month
        },
        'products': {
            'total': 8,  # Electronics catalog size
            'top_selling': [
                {'name': 'iPhone 15 Pro Max', 'sales': 847},
                {'name': 'MacBook Pro 16"', 'sales': 623},
                {'name': 'PlayStation 5', 'sales': 592},
                {'name': 'Samsung Galaxy S24 Ultra', 'sales': 438},
                {'name': 'iPad Pro 12.9"', 'sales': 367}
            ]
        },
        'revenue': {
            'daily': [
                {'date': (datetime.now() - timedelta(days=i)).strftime('%Y-%m-%d'), 
                 'amount': random.randint(15000, 25000)} 
                for i in range(7, 0, -1)
            ]
        }
    }
    
    return jsonify(data)

@analytics_bp.route('/reports', methods=['GET'])
@jwt_required()
def get_reports():
    """Get analytics reports"""
    report_type = request.args.get('type', 'sales')
    
    if report_type == 'sales':
        data = {
            'type': 'sales',
            'period': 'monthly',
            'data': [
                {'month': 'Jan', 'sales': random.randint(5000, 15000)},
                {'month': 'Feb', 'sales': random.randint(5000, 15000)},
                {'month': 'Mar', 'sales': random.randint(5000, 15000)},
                {'month': 'Apr', 'sales': random.randint(5000, 15000)},
                {'month': 'May', 'sales': random.randint(5000, 15000)},
                {'month': 'Jun', 'sales': random.randint(5000, 15000)}
            ]
        }
    elif report_type == 'users':
        data = {
            'type': 'users',
            'period': 'weekly',
            'data': [
                {'week': f'Week {i}', 'new_users': random.randint(10, 50)} 
                for i in range(1, 13)
            ]
        }
    else:
        data = {'error': 'Invalid report type'}
        return jsonify(data), 400
    
    return jsonify(data)

@analytics_bp.route('/metrics', methods=['GET'])
@jwt_required()
def get_metrics():
    """Get system metrics"""
    metrics = {
        'response_time': round(random.uniform(50, 200), 2),
        'throughput': random.randint(100, 1000),
        'error_rate': round(random.uniform(0, 5), 2),
        'uptime': round(random.uniform(95, 99.9), 2),
        'database_connections': random.randint(5, 20),
        'memory_usage': round(random.uniform(30, 80), 2),
        'cpu_usage': round(random.uniform(10, 60), 2)
    }
    
    return jsonify(metrics)
