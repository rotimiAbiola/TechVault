import axios, { AxiosInstance } from 'axios'

const API_BASE_URL = import.meta.env.VITE_API_URL || 'http://localhost:5000/api'

// Create axios instance with base configuration
const apiClient: AxiosInstance = axios.create({
  baseURL: API_BASE_URL,
  timeout: 10000,
  headers: {
    'Content-Type': 'application/json',
  },
})

// Request interceptor to add auth token
apiClient.interceptors.request.use(
  (config) => {
    const token = localStorage.getItem('token')
    if (token) {
      config.headers.Authorization = `Bearer ${token}`
    }
    return config
  },
  (error) => {
    return Promise.reject(error)
  }
)

// Response interceptor for error handling
apiClient.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401) {
      localStorage.removeItem('token')
      window.location.href = '/login'
    }
    return Promise.reject(error)
  }
)

// Auth API endpoints
export const authAPI = {
  login: async (username: string, password: string) => {
    const response = await apiClient.post('/auth/login', { username, password })
    return response.data
  },

  register: async (username: string, email: string, password: string) => {
    const response = await apiClient.post('/auth/register', { username, email, password })
    return response.data
  },

  getProfile: async (token: string) => {
    const response = await apiClient.get('/auth/profile', {
      headers: { Authorization: `Bearer ${token}` }
    })
    return response.data
  },

  refreshToken: async () => {
    const response = await apiClient.post('/auth/refresh')
    return response.data
  },
}

// Products API endpoints
export const productsAPI = {
  getProducts: async (params?: { page?: number; limit?: number; search?: string }) => {
    const response = await apiClient.get('/products', { params })
    return response.data
  },

  getProduct: async (id: number) => {
    const response = await apiClient.get(`/products/${id}`)
    return response.data
  },

  createProduct: async (productData: any) => {
    const response = await apiClient.post('/products', productData)
    return response.data
  },

  updateProduct: async (id: number, productData: any) => {
    const response = await apiClient.put(`/products/${id}`, productData)
    return response.data
  },

  deleteProduct: async (id: number) => {
    const response = await apiClient.delete(`/products/${id}`)
    return response.data
  },

  searchProducts: async (query: string) => {
    const response = await apiClient.get(`/products/search?q=${encodeURIComponent(query)}`)
    return response.data
  },
}

// Analytics API endpoints
export const analyticsAPI = {
  getDashboardStats: async () => {
    const response = await apiClient.get('/analytics/dashboard')
    return response.data
  },

  getUserAnalytics: async (timeRange: string) => {
    const response = await apiClient.get(`/analytics/users?range=${timeRange}`)
    return response.data
  },

  getProductAnalytics: async (timeRange: string) => {
    const response = await apiClient.get(`/analytics/products?range=${timeRange}`)
    return response.data
  },
}

// Health check endpoint
export const healthAPI = {
  checkHealth: async () => {
    const response = await apiClient.get('/health')
    return response.data
  },
}

export default apiClient
