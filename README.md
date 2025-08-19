# TechVault - Microservices E-commerce Platform

TechVault is a modern e-commerce platform built with microservices architecture, featuring a React frontend and multiple Python Flask backend services.

## Architecture Overview

### Microservices
- **API Gateway** (Port 5000) - Routes requests to appropriate microservices
- **Auth Service** (Port 5001) - User authentication and authorization
- **Product Service** (Port 5002) - Product catalog management
- **Cart Service** (Port 5003) - Shopping cart functionality
- **Payment Service** (Port 5004) - Payment processing
- **Order Service** (Port 5005) - Order management

### Frontend
- **React App** (Port 3000) - Modern React TypeScript frontend with Material-UI

### Infrastructure
- **PostgreSQL** (Port 5432) - Primary database with separate schemas for each service
- **Redis** (Port 6379) - Caching and session storage

## Features

### Public Access
- Browse products without authentication
- View product details and categories
- Add items to cart (session-based for guests)

### Authenticated Features
- User registration and login
- Persistent cart across sessions
- Secure checkout and payment processing
- Order history and tracking
- User profile management

## Getting Started

### Prerequisites
- Docker and Docker Compose
- Node.js 18+ (for frontend development)
- Python 3.11+ (for backend development)

### Quick Start with Docker

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd react-python-app
   ```

2. **Start all services**
   ```bash
   docker compose up --build
   ```

3. **Access the application**
   - Frontend: http://localhost:3000
   - API Gateway: http://localhost:5000
   - Health Check: http://localhost:5000/health

### Service URLs

| Service | URL | Description |
|---------|-----|-------------|
| Frontend | http://localhost:3000 | React application |
| API Gateway | http://localhost:5000 | Main API endpoint |
| Auth Service | http://localhost:5001 | Authentication |
| Product Service | http://localhost:5002 | Product catalog |
| Cart Service | http://localhost:5003 | Shopping cart |
| Payment Service | http://localhost:5004 | Payment processing |
| Order Service | http://localhost:5005 | Order management |

## API Endpoints

### Authentication
- `POST /api/register` - User registration
- `POST /api/login` - User login
- `GET /api/profile` - Get user profile
- `PUT /api/profile` - Update user profile

### Products (Public)
- `GET /api/products` - List products with pagination and filters
- `GET /api/products/{id}` - Get product details
- `GET /api/products/categories` - Get product categories
- `GET /api/products/brands` - Get product brands

### Cart
- `GET /api/cart` - Get current cart
- `POST /api/cart/items` - Add item to cart
- `PUT /api/cart/items/{id}` - Update cart item
- `DELETE /api/cart/items/{id}` - Remove cart item
- `DELETE /api/cart/clear` - Clear cart

### Payment (Authenticated)
- `POST /api/payment/create-intent` - Create payment intent
- `POST /api/payment/process` - Process payment
- `GET /api/payment/{id}` - Get payment details
- `GET /api/payment/user/history` - Payment history

### Orders (Authenticated)
- `GET /api/orders` - List user orders
- `POST /api/orders` - Create new order
- `GET /api/orders/{order_number}` - Get order details
- `POST /api/orders/{order_number}/confirm` - Confirm order
- `POST /api/orders/{order_number}/cancel` - Cancel order

## Development

### Project Structure
```
├── frontend/                 # React TypeScript frontend
├── gateway/                  # API Gateway service
├── auth-service/            # Authentication microservice
├── product-service/         # Product catalog microservice
├── cart-service/            # Shopping cart microservice
├── payment-service/         # Payment processing microservice
├── order-service/           # Order management microservice
├── scripts/                 # Database initialization scripts
├── compose.yml             # Production deployment configuration
└── README.md
```

### Environment Variables

Each service can be configured with environment variables:

**Database Configuration:**
- `DATABASE_URL` - PostgreSQL connection string
- `REDIS_URL` - Redis connection string

**Security:**
- `JWT_SECRET_KEY` - JWT signing secret
- `SECRET_KEY` - Flask session secret

**Service Discovery:**
- `AUTH_SERVICE_URL` - Auth service URL
- `PRODUCT_SERVICE_URL` - Product service URL
- `CART_SERVICE_URL` - Cart service URL
- `PAYMENT_SERVICE_URL` - Payment service URL
- `ORDER_SERVICE_URL` - Order service URL

### Database Schema

Each microservice has its own database:
- `authdb` - User accounts and authentication
- `productdb` - Product catalog and inventory
- `cartdb` - Shopping cart data
- `paymentdb` - Payment transactions
- `orderdb` - Order information and history

## Security Features

- JWT-based authentication
- Password hashing with secure algorithms
- CORS protection
- Input validation and sanitization
- Database connection security
- Container security with non-root users

## Monitoring and Health Checks

- Individual service health endpoints: `/health`
- Aggregated health check: `http://localhost:5000/health`
- Docker health checks for all services
- Service dependency management

## Sample Products

The platform comes pre-loaded with sample TechVault electronics including:
- Latest smartphones (iPhone 15 Pro Max, Samsung Galaxy S24 Ultra)
- Laptops (MacBook Pro 16", Dell XPS 13)
- Gaming consoles (PlayStation 5, Nintendo Switch OLED)
- Audio equipment (AirPods Pro 3rd Gen)
- Tablets (iPad Pro 12.9")

## Production Deployment

The application is production-ready with:
- Multi-stage Docker builds
- Security hardening
- Health checks
- Proper logging
- Error handling
- Database connection pooling

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes and test thoroughly
4. Submit a pull request

## License

This project is licensed under the MIT License.
