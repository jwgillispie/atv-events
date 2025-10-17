const express = require('express');
const cors = require('cors');
const axios = require('axios');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors({
  origin: [
    'http://localhost:3000',
    'http://localhost:8080', 
    'http://localhost:5000',
    'http://127.0.0.1:3000',
    'http://127.0.0.1:8080',
    'http://127.0.0.1:5000',
    'https://hipop-markets.web.app',
    'https://hipop-markets.firebaseapp.com',
    'https://hipop-markets-staging.web.app',
    'https://hipop-markets-staging.firebaseapp.com',
    'https://hipop-markets-website.web.app',
    'https://hipop-markets-website.firebaseapp.com',
    /^http:\/\/localhost:\d+$/,
    /^http:\/\/127\.0\.0\.1:\d+$/
  ],
  credentials: true
}));
app.use(express.json());

// Google Places API autocomplete endpoint
app.get('/api/places/autocomplete', async (req, res) => {
  try {
    const { input } = req.query;
    
    if (!input || input.length < 3) {
      return res.json({ predictions: [] });
    }

    const apiKey = process.env.GOOGLE_MAPS_API_KEY;
    if (!apiKey) {
      return res.status(500).json({ error: 'Google Maps API key not configured' });
    }

    const baseUrl = 'https://maps.googleapis.com/maps/api/place/autocomplete/json';
    const url = `${baseUrl}?input=${encodeURIComponent(input)}&key=${apiKey}&types=establishment|geocode&components=country:us&location=33.749,-84.388&radius=50000`;
    
    const response = await axios.get(url);
    
    if (response.data.status === 'OK') {
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
      res.status(400).json({ error: response.data.status });
    }
  } catch (error) {
    console.error('Error in places autocomplete:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Google Places API place details endpoint
app.get('/api/places/details', async (req, res) => {
  try {
    const { place_id } = req.query;
    
    if (!place_id) {
      return res.status(400).json({ error: 'place_id is required' });
    }

    const apiKey = process.env.GOOGLE_MAPS_API_KEY;
    if (!apiKey) {
      return res.status(500).json({ error: 'Google Maps API key not configured' });
    }

    const baseUrl = 'https://maps.googleapis.com/maps/api/place/details/json';
    const url = `${baseUrl}?place_id=${place_id}&key=${apiKey}&fields=place_id,name,formatted_address,geometry`;
    
    const response = await axios.get(url);
    
    if (response.data.status === 'OK') {
      const result = response.data.result;
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
      res.status(400).json({ error: response.data.status });
    }
  } catch (error) {
    console.error('Error in place details:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'OK', timestamp: new Date().toISOString() });
});

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});