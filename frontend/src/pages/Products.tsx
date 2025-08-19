import React, { useEffect, useState } from 'react';
import { 
  Typography, 
  Box, 
  Card, 
  CardContent, 
  Grid, 
  Alert, 
  CircularProgress,
  Chip
} from '@mui/material';
import { productsAPI } from '../services/api';
import { useAuth } from '../contexts/AuthContext';

interface Product {
  id: number;
  name: string;
  price: number;
  description: string;
}

const Products: React.FC = () => {
  const [products, setProducts] = useState<Product[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const { isAuthenticated } = useAuth();

  useEffect(() => {
    const fetchProducts = async () => {
      try {
        if (!isAuthenticated) {
          setError('Please log in to view products');
          setLoading(false);
          return;
        }

        const data = await productsAPI.getProducts();
        setProducts(data.products || []);
        setError(null);
      } catch (err: any) {
        console.error('Failed to fetch products:', err);
        if (err.response?.status === 401) {
          setError('Authentication required. Please log in.');
        } else {
          setError('Failed to load products. Please try again later.');
        }
      } finally {
        setLoading(false);
      }
    };

    fetchProducts();
  }, [isAuthenticated]);

  if (loading) {
    return (
      <Box sx={{ display: 'flex', justifyContent: 'center', mt: 4 }}>
        <CircularProgress />
      </Box>
    );
  }

  return (
    <Box>
      <Typography variant="h4" component="h1" gutterBottom>
        TechVault Products 📱💻🎮
      </Typography>
      
      {error ? (
        <Alert severity="error" sx={{ mb: 2 }}>
          {error}
        </Alert>
      ) : !isAuthenticated ? (
        <Alert severity="warning" sx={{ mb: 2 }}>
          Please log in to view products.
        </Alert>
      ) : products.length === 0 ? (
        <Alert severity="info" sx={{ mb: 2 }}>
          No products available at the moment.
        </Alert>
      ) : (
        <Grid container spacing={3}>
          {products.map((product) => (
            <Grid item xs={12} sm={6} md={4} key={product.id}>
              <Card>
                <CardContent>
                  <Typography variant="h6" component="h2" gutterBottom>
                    {product.name}
                  </Typography>
                  <Typography variant="body2" color="text.secondary" paragraph>
                    {product.description}
                  </Typography>
                  <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                    <Chip 
                      label={`$${product.price.toFixed(2)}`} 
                      color="primary" 
                      variant="outlined"
                    />
                    <Typography variant="caption" color="text.secondary">
                      ID: {product.id}
                    </Typography>
                  </Box>
                </CardContent>
              </Card>
            </Grid>
          ))}
        </Grid>
      )}
    </Box>
  );
};

export default Products;
