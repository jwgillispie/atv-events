const express = require('express');
const cors = require('cors');
const axios = require('axios');
const fs = require('fs');
const path = require('path');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;

// Enhanced logging functionality
class Logger {
  constructor() {
    this.logFile = path.join(__dirname, 'server.log');
  }

  log(level, message, extra = {}) {
    const timestamp = new Date().toISOString();
    const logEntry = {
      timestamp,
      level,
      message,
      ...extra
    };
    
    // Console output with colors
    const colors = {
      INFO: '\x1b[36m',   // Cyan
      WARN: '\x1b[33m',   // Yellow
      ERROR: '\x1b[31m',  // Red
      SUCCESS: '\x1b[32m' // Green
    };
    
    console.log(`${colors[level] || ''}[${timestamp}] ${level}: ${message}\x1b[0m`);
    
    // File output
    fs.appendFileSync(this.logFile, JSON.stringify(logEntry) + '\n');
  }

  info(message, extra) { this.log('INFO', message, extra); }
  warn(message, extra) { this.log('WARN', message, extra); }
  error(message, extra) { this.log('ERROR', message, extra); }
  success(message, extra) { this.log('SUCCESS', message, extra); }
}

const logger = new Logger();

// Request logging middleware
app.use((req, res, next) => {
  const start = Date.now();
  
  res.on('finish', () => {
    const duration = Date.now() - start;
    const logData = {
      method: req.method,
      url: req.url,
      status: res.statusCode,
      duration: `${duration}ms`,
      userAgent: req.get('User-Agent'),
      ip: req.ip
    };
    
    if (res.statusCode >= 400) {
      logger.error(`HTTP ${res.statusCode}`, logData);
    } else {
      logger.info(`HTTP ${res.statusCode}`, logData);
    }
  });
  
  next();
});

// Simple CORS handling - allow all origins for now
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Credentials', 'true');
  res.header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  res.header('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept, Authorization');
  
  // Handle preflight requests
  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }
  
  next();
});
app.use(express.json());

// Request counter for monitoring
let requestCount = 0;
let lastReset = Date.now();

// Statistics tracking
const stats = {
  requests: {
    total: 0,
    autocomplete: 0,
    details: 0,
    health: 0
  },
  errors: {
    total: 0,
    apiKey: 0,
    google: 0,
    network: 0
  },
  startTime: new Date()
};

// Google Places API autocomplete endpoint
app.get('/api/places/autocomplete', async (req, res) => {
  stats.requests.total++;
  stats.requests.autocomplete++;
  
  try {
    const { input } = req.query;
    
    logger.info(`Places autocomplete request`, { input });
    
    if (!input || input.length < 3) {
      logger.warn('Autocomplete request with insufficient input', { input });
      return res.json({ predictions: [] });
    }

    const apiKey = process.env.GOOGLE_MAPS_API_KEY;
    if (!apiKey) {
      stats.errors.total++;
      stats.errors.apiKey++;
      logger.error('Google Maps API key not configured');
      return res.status(500).json({ error: 'Google Maps API key not configured' });
    }

    const baseUrl = 'https://maps.googleapis.com/maps/api/place/autocomplete/json';
    const url = `${baseUrl}?input=${encodeURIComponent(input)}&key=${apiKey}&types=establishment|geocode&components=country:us&location=33.749,-84.388&radius=50000`;
    
    const startTime = Date.now();
    const response = await axios.get(url);
    const apiDuration = Date.now() - startTime;
    
    if (response.data.status === 'OK') {
      const predictionCount = response.data.predictions?.length || 0;
      logger.success(`Autocomplete successful`, { 
        input, 
        predictions: predictionCount,
        apiDuration: `${apiDuration}ms`
      });
      
      res.json({
        predictions: response.data.predictions.map(prediction => ({
          place_id: prediction.place_id,
          description: prediction.description,
          structured_formatting: {
            main_text: prediction.structured_formatting.main_text,
            secondary_text: prediction.structured_formatting.secondary_text || ''
          }
        }))
      });
    } else {
      stats.errors.total++;
      stats.errors.google++;
      logger.error(`Google API error`, { status: response.data.status, input });
      res.status(400).json({ error: response.data.status });
    }
  } catch (error) {
    stats.errors.total++;
    stats.errors.network++;
    logger.error('Autocomplete request failed', { error: error.message, input: req.query.input });
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Google Places API place details endpoint
app.get('/api/places/details', async (req, res) => {
  stats.requests.total++;
  stats.requests.details++;
  
  try {
    const { place_id } = req.query;
    
    logger.info(`Place details request`, { place_id });
    
    if (!place_id) {
      logger.warn('Details request without place_id');
      return res.status(400).json({ error: 'place_id is required' });
    }

    const apiKey = process.env.GOOGLE_MAPS_API_KEY;
    if (!apiKey) {
      stats.errors.total++;
      stats.errors.apiKey++;
      logger.error('Google Maps API key not configured');
      return res.status(500).json({ error: 'Google Maps API key not configured' });
    }

    const baseUrl = 'https://maps.googleapis.com/maps/api/place/details/json';
    const url = `${baseUrl}?place_id=${place_id}&key=${apiKey}&fields=place_id,name,formatted_address,geometry`;
    
    const startTime = Date.now();
    const response = await axios.get(url);
    const apiDuration = Date.now() - startTime;
    
    if (response.data.status === 'OK') {
      const result = response.data.result;
      logger.success(`Place details successful`, { 
        place_id, 
        name: result.name,
        apiDuration: `${apiDuration}ms`
      });
      
      res.json({
        result: {
          place_id: result.place_id,
          name: result.name || result.formatted_address,
          formatted_address: result.formatted_address,
          geometry: {
            location: {
              lat: result.geometry.location.lat,
              lng: result.geometry.location.lng
            }
          }
        }
      });
    } else {
      stats.errors.total++;
      stats.errors.google++;
      logger.error(`Google API error`, { status: response.data.status, place_id });
      res.status(400).json({ error: response.data.status });
    }
  } catch (error) {
    stats.errors.total++;
    stats.errors.network++;
    logger.error('Details request failed', { error: error.message, place_id: req.query.place_id });
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Enhanced health check endpoint
app.get('/health', (req, res) => {
  stats.requests.total++;
  stats.requests.health++;
  
  const uptime = Date.now() - stats.startTime.getTime();
  const uptimeSeconds = Math.floor(uptime / 1000);
  
  const healthData = {
    status: 'OK',
    timestamp: new Date().toISOString(),
    uptime: {
      ms: uptime,
      seconds: uptimeSeconds,
      human: `${Math.floor(uptimeSeconds / 3600)}h ${Math.floor((uptimeSeconds % 3600) / 60)}m ${uptimeSeconds % 60}s`
    },
    server: {
      pid: process.pid,
      memory: process.memoryUsage(),
      version: process.version,
      platform: process.platform
    },
    stats,
    environment: {
      hasApiKey: !!process.env.GOOGLE_MAPS_API_KEY,
      port: PORT,
      nodeEnv: process.env.NODE_ENV || 'development'
    }
  };
  
  logger.info('Health check requested');
  res.json(healthData);
});

// Statistics endpoint
app.get('/api/stats', (req, res) => {
  const uptime = Date.now() - stats.startTime.getTime();
  res.json({
    ...stats,
    uptime: {
      ms: uptime,
      human: `${Math.floor(uptime / 3600000)}h ${Math.floor((uptime % 3600000) / 60000)}m`
    }
  });
});

// Logs endpoint (last 100 entries)
app.get('/api/logs', (req, res) => {
  try {
    const logFile = path.join(__dirname, 'server.log');
    if (fs.existsSync(logFile)) {
      const logs = fs.readFileSync(logFile, 'utf8')
        .split('\n')
        .filter(line => line.trim())
        .slice(-100)
        .map(line => {
          try {
            return JSON.parse(line);
          } catch (e) {
            return { message: line };
          }
        });
      res.json({ logs });
    } else {
      res.json({ logs: [] });
    }
  } catch (error) {
    logger.error('Failed to read logs', { error: error.message });
    res.status(500).json({ error: 'Failed to read logs' });
  }
});

// Error handling middleware
app.use((error, req, res, next) => {
  stats.errors.total++;
  logger.error('Unhandled error', { 
    error: error.message, 
    stack: error.stack,
    url: req.url,
    method: req.method
  });
  res.status(500).json({ error: 'Internal server error' });
});

// 404 handler
app.use((req, res) => {
  logger.warn('Route not found', { url: req.url, method: req.method });
  res.status(404).json({ error: 'Route not found' });
});

// Graceful shutdown
process.on('SIGINT', () => {
  logger.info('Received SIGINT, shutting down gracefully');
  const shutdownTime = Date.now() - stats.startTime.getTime();
  logger.info(`Server ran for ${Math.floor(shutdownTime / 1000)} seconds`);
  logger.info(`Total requests processed: ${stats.requests.total}`);
  process.exit(0);
});

process.on('SIGTERM', () => {
  logger.info('Received SIGTERM, shutting down gracefully');
  process.exit(0);
});

// Start server
app.listen(PORT, () => {
  logger.success(`Server running on port ${PORT}`);
  logger.info('Available endpoints:', {
    health: `http://localhost:${PORT}/health`,
    autocomplete: `http://localhost:${PORT}/api/places/autocomplete?input=query`,
    details: `http://localhost:${PORT}/api/places/details?place_id=id`,
    stats: `http://localhost:${PORT}/api/stats`,
    logs: `http://localhost:${PORT}/api/logs`
  });
});