import React from 'react';
import { Typography, Box, Button, Card, CardContent, Grid, Container } from '@mui/material';
import { Link } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';

const Home: React.FC = () => {
  const { isAuthenticated } = useAuth();

  return (
    <Container maxWidth="lg">
      <Box sx={{ textAlign: 'center', py: 8 }}>
        <Typography variant="h2" component="h1" gutterBottom>
          Welcome to TechVault 🔐
        </Typography>
        <Typography variant="h5" component="h2" gutterBottom color="text.secondary" sx={{ mb: 6 }}>
          Your Premium Electronics & Gadgets Store
        </Typography>

        {/* Features Grid */}
        <Grid container spacing={4} sx={{ mb: 6 }}>
          <Grid item xs={12} md={4}>
            <Card sx={{ height: '100%', p: 2 }}>
              <CardContent>
                <Typography variant="h4" component="h3" gutterBottom>
                  📱
                </Typography>
                <Typography variant="h6" component="h4" gutterBottom>
                  Latest Smartphones
                </Typography>
                <Typography variant="body1" color="text.secondary">
                  Discover the newest iPhone, Samsung Galaxy, and premium smartphones with cutting-edge technology.
                </Typography>
              </CardContent>
            </Card>
          </Grid>
          <Grid item xs={12} md={4}>
            <Card sx={{ height: '100%', p: 2 }}>
              <CardContent>
                <Typography variant="h4" component="h3" gutterBottom>
                  �
                </Typography>
                <Typography variant="h6" component="h4" gutterBottom>
                  Professional Laptops
                </Typography>
                <Typography variant="body1" color="text.secondary">
                  MacBook Pro, Dell XPS, and high-performance laptops for professionals and creators.
                </Typography>
              </CardContent>
            </Card>
          </Grid>
          <Grid item xs={12} md={4}>
            <Card sx={{ height: '100%', p: 2 }}>
              <CardContent>
                <Typography variant="h4" component="h3" gutterBottom>
                  🎮
                </Typography>
                <Typography variant="h6" component="h4" gutterBottom>
                  Gaming Consoles
                </Typography>
                <Typography variant="body1" color="text.secondary">
                  PlayStation 5, Nintendo Switch, and the latest gaming accessories for ultimate entertainment.
                </Typography>
              </CardContent>
            </Card>
          </Grid>
        </Grid>

        {/* Call to Action */}
        <Box sx={{ mt: 6 }}>
          {isAuthenticated ? (
            <>
              <Button
                variant="contained"
                size="large"
                component={Link}
                to="/products"
                sx={{ mr: 2, mb: 2 }}
              >
                Browse Products
              </Button>
              <Button
                variant="outlined"
                size="large"
                component={Link}
                to="/dashboard"
                sx={{ mb: 2 }}
              >
                View Dashboard
              </Button>
            </>
          ) : (
            <>
              <Button
                variant="contained"
                size="large"
                component={Link}
                to="/register"
                sx={{ mr: 2, mb: 2 }}
              >
                Join TechVault
              </Button>
              <Button
                variant="outlined"
                size="large"
                component={Link}
                to="/login"
                sx={{ mb: 2 }}
              >
                Sign In
              </Button>
            </>
          )}
        </Box>

        {/* Status Link */}
        <Box sx={{ mt: 4 }}>
          <Typography variant="body2" color="text.secondary">
            Check our{' '}
            <Link to="/status" style={{ textDecoration: 'none', color: 'inherit', fontWeight: 'bold' }}>
              system status
            </Link>
            {' '}for real-time service monitoring
          </Typography>
        </Box>
      </Box>
    </Container>
  );
};

export default Home;
