import React, { useEffect, useState } from 'react';
import { 
  Typography, 
  Box, 
  Grid, 
  Card, 
  CardContent, 
  Alert,
  CircularProgress,
  Chip,
  Container
} from '@mui/material';
import { healthAPI } from '../services/api';

interface HealthStatus {
  status: string;
  timestamp: string;
  services: {
    [key: string]: {
      status: string;
      message: string;
    };
  };
}

const Status: React.FC = () => {
  const [healthData, setHealthData] = useState<HealthStatus | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const fetchHealthData = async () => {
      try {
        const data = await healthAPI.checkHealth();
        setHealthData(data);
        setError(null);
      } catch (err: any) {
        console.error('Failed to fetch health data:', err);
        setError('Failed to load system status. Please try again later.');
      } finally {
        setLoading(false);
      }
    };

    fetchHealthData();
    // Refresh every 30 seconds
    const interval = setInterval(fetchHealthData, 30000);
    return () => clearInterval(interval);
  }, []);

  if (loading) {
    return (
      <Container>
        <Box sx={{ display: 'flex', justifyContent: 'center', mt: 4 }}>
          <CircularProgress />
        </Box>
      </Container>
    );
  }

  return (
    <Container>
      <Box sx={{ py: 4 }}>
        <Typography variant="h3" component="h1" gutterBottom align="center">
          TechVault System Status 📊
        </Typography>
        <Typography variant="h6" component="h2" gutterBottom color="text.secondary" align="center" sx={{ mb: 4 }}>
          Real-time monitoring of our services and infrastructure
        </Typography>

        {error ? (
          <Alert severity="error" sx={{ mb: 4 }}>
            {error}
          </Alert>
        ) : healthData ? (
          <>
            {/* Overall Status */}
            <Card sx={{ mb: 4 }}>
              <CardContent>
                <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'center', mb: 2 }}>
                  <Typography variant="h4" component="h3" sx={{ mr: 2 }}>
                    Overall Status:
                  </Typography>
                  <Chip 
                    label={healthData.status.toUpperCase()}
                    color={healthData.status === 'healthy' ? 'success' : 'error'}
                    size="medium"
                    sx={{ fontWeight: 'bold', fontSize: '1.1rem', px: 2, py: 1 }}
                  />
                </Box>
                <Typography variant="body2" color="text.secondary" align="center">
                  Last updated: {new Date(healthData.timestamp).toLocaleString()}
                </Typography>
              </CardContent>
            </Card>

            {/* Individual Services */}
            <Typography variant="h5" component="h3" gutterBottom sx={{ mb: 3 }}>
              Service Details
            </Typography>
            <Grid container spacing={3}>
              {Object.entries(healthData.services).map(([serviceName, serviceData]) => (
                <Grid item xs={12} md={6} lg={4} key={serviceName}>
                  <Card sx={{ height: '100%' }}>
                    <CardContent>
                      <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', mb: 2 }}>
                        <Typography variant="h6" component="h4" sx={{ textTransform: 'capitalize' }}>
                          {serviceName}
                        </Typography>
                        <Chip 
                          label={serviceData.status}
                          color={serviceData.status === 'healthy' ? 'success' : 'error'}
                          size="small"
                        />
                      </Box>
                      <Typography variant="body2" color="text.secondary">
                        {serviceData.message}
                      </Typography>
                    </CardContent>
                  </Card>
                </Grid>
              ))}
            </Grid>

            {/* Refresh Info */}
            <Box sx={{ mt: 4, textAlign: 'center' }}>
              <Typography variant="body2" color="text.secondary">
                🔄 Status automatically refreshes every 30 seconds
              </Typography>
            </Box>
          </>
        ) : (
          <Alert severity="info">
            No status data available at the moment.
          </Alert>
        )}
      </Box>
    </Container>
  );
};

export default Status;
