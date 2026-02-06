const axios = require('axios');
const config = require('../config/environment');
const logger = require('../utils/logger');

class LocationService {
  constructor() {
    this.apiKey = config.googleMapsApiKey;
    this.geocodingUrl = 'https://maps.googleapis.com/maps/api/geocode/json';
    this.distanceMatrixUrl = 'https://maps.googleapis.com/maps/api/distancematrix/json';
  }

  async geocodeAddress(address) {
    try {
      const response = await axios.get(this.geocodingUrl, {
        params: {
          address,
          key: this.apiKey
        }
      });

      if (response.data.results.length === 0) {
        throw new Error('Address not found');
      }

      const location = response.data.results[0].geometry.location;
      return {
        lat: location.lat,
        lng: location.lng,
        formattedAddress: response.data.results[0].formatted_address
      };
    } catch (error) {
      logger.error('Geocoding error:', error);
      throw error;
    }
  }

  async calculateTravelTime(origin, destination) {
    try {
      const response = await axios.get(this.distanceMatrixUrl, {
        params: {
          origins: `${origin.lat},${origin.lng}`,
          destinations: `${destination.lat},${destination.lng}`,
          mode: 'driving',
          key: this.apiKey
        }
      });

      const result = response.data.rows[0].elements[0];
      return {
        duration: result.duration.value, // seconds
        distance: result.distance.value, // meters
        durationText: result.duration.text,
        distanceText: result.distance.text
      };
    } catch (error) {
      logger.error('Travel time calculation error:', error);
      throw error;
    }
  }

  async getNearbyTasks(location, radius) {
    try {
      // Implementation to find tasks within radius
      // Using MongoDB geospatial queries
    } catch (error) {
      logger.error('Error finding nearby tasks:', error);
      throw error;
    }
  }
}

module.exports = new LocationService(); 