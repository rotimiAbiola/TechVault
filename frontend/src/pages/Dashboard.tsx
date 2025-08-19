import React, { useEffect, useState } from 'react';
import { 
  Typography, 
  Box, 
  Grid, 
  Card, 
  CardContent, 
  Alert,
  CircularProgress,
  Chip
} from '@mui/material';
import { analyticsAPI } from '../services/api';
import { useAuth } from '../contexts/AuthContext';

interface DashboardData {
  sales: {
    total: number;
    this_month: number;
    growth: number;
  };
  users: {
    total: number;
    active: number;
    new: number;
  };
  products: {
    total: number;
    top_selling: Array<{
      name: string;
      sales: number;
    }>;
  };
}

const Dashboard: React.FC = () => {
  const [dashboardData, setDashboardData] = useState<DashboardData | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const { isAuthenticated } = useAuth();

  useEffect(() => {
    const fetchDashboardData = async () => {
      try {
        if (!isAuthenticated) {
          setError('Please log in to view dashboard');
          setLoading(false);
          return;
        }

        const data = await analyticsAPI.getDashboardStats();
        setDashboardData(data);
        setError(null);
      } catch (err: any) {
        console.error('Failed to fetch dashboard data:', err);
        if (err.response?.status === 401) {
          setError('Authentication required. Please log in.');
        } else {
          setError('Failed to load dashboard data. Please try again later.');
        }
      } finally {
        setLoading(false);
      }
    };

    fetchDashboardData();
  }, [isAuthenticated]);

  if (loading) {
    return (
      <Box sx={{ display: 'flex', justifyContent: 'center', mt: 4 }}>
        <CircularProgress />
      </Box>
    );
  }

  if (error) {
    return (
      <Alert severity="error" sx={{ mt: 2 }}>
        {error}
      </Alert>
    );
  }

  if (!dashboardData) {
    return (
      <Alert severity="info" sx={{ mt: 2 }}>
        No dashboard data available.
      </Alert>
    );
  }

  return (
    <Box>
      <Typography variant="h4" component="h1" gutterBottom>
        TechVault Analytics 📊
      </Typography>
      
      <Grid container spacing={3}>
        {/* Sales Card */}
        <Grid item xs={12} md={4}>
          <Card>
            <CardContent>
              <Typography variant="h6" gutterBottom>
                Sales
              </Typography>
              <Typography variant="h4" color="primary">
                ${dashboardData.sales.total.toLocaleString()}
              </Typography>
              <Typography variant="body2" color="text.secondary">
                This month: ${dashboardData.sales.this_month.toLocaleString()}
              </Typography>
              <Chip 
                label={`${dashboardData.sales.growth > 0 ? '+' : ''}${dashboardData.sales.growth}%`}
                color={dashboardData.sales.growth > 0 ? 'success' : 'error'}
                size="small"
                sx={{ mt: 1 }}
              />
            </CardContent>
          </Card>
        </Grid>

        {/* Users Card */}
        <Grid item xs={12} md={4}>
          <Card>
            <CardContent>
              <Typography variant="h6" gutterBottom>
                Users
              </Typography>
              <Typography variant="h4" color="primary">
                {dashboardData.users.total.toLocaleString()}
              </Typography>
              <Typography variant="body2" color="text.secondary">
                Active: {dashboardData.users.active}
              </Typography>
              <Typography variant="body2" color="text.secondary">
                New: {dashboardData.users.new}
              </Typography>
            </CardContent>
          </Card>
        </Grid>

        {/* Products Card */}
        <Grid item xs={12} md={4}>
          <Card>
            <CardContent>
              <Typography variant="h6" gutterBottom>
                Products
              </Typography>
              <Typography variant="h4" color="primary">
                {dashboardData.products.total}
              </Typography>
              <Typography variant="subtitle2" sx={{ mt: 2, mb: 1 }}>
                Top Selling:
              </Typography>
              {dashboardData.products.top_selling.map((product, index) => (
                <Box key={index} sx={{ display: 'flex', justifyContent: 'space-between', mb: 0.5 }}>
                  <Typography variant="body2">{product.name}</Typography>
                  <Typography variant="body2" color="text.secondary">
                    {product.sales}
                  </Typography>
                </Box>
              ))}
            </CardContent>
          </Card>
        </Grid>
      </Grid>
    </Box>
  );
};

export default Dashboard;
