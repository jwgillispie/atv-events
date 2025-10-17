#!/usr/bin/env node

const { exec, spawn } = require('child_process');
const fs = require('fs');
const path = require('path');

const commands = {
  start: () => {
    console.log('🚀 Starting server...');
    const server = spawn('node', ['index.js'], { stdio: 'inherit' });
    
    process.on('SIGINT', () => {
      console.log('\n🛑 Shutting down server...');
      server.kill();
      process.exit();
    });
  },

  dev: () => {
    console.log('🔄 Starting development server with auto-reload...');
    const server = spawn('npx', ['nodemon', 'index.js'], { stdio: 'inherit' });
    
    process.on('SIGINT', () => {
      console.log('\n🛑 Shutting down development server...');
      server.kill();
      process.exit();
    });
  },

  status: () => {
    console.log('📊 Checking server status...');
    exec('curl -s http://localhost:3000/health', (error, stdout, stderr) => {
      if (error) {
        console.log('❌ Server is not running');
        console.log('   Start it with: npm start');
      } else {
        console.log('✅ Server is running');
        console.log('   Response:', stdout);
      }
    });
  },

  test: () => {
    console.log('🧪 Testing API endpoints...');
    
    // Test health endpoint
    exec('curl -s http://localhost:3000/health', (error, stdout) => {
      if (error) {
        console.log('❌ Health check failed - server not running');
        return;
      }
      console.log('✅ Health check passed');
      
      // Test places endpoint
      exec('curl -s "http://localhost:3000/api/places/autocomplete?input=atlanta"', (error, stdout) => {
        if (error) {
          console.log('❌ Places API test failed');
        } else {
          const response = JSON.parse(stdout);
          if (response.predictions && response.predictions.length > 0) {
            console.log('✅ Places API working');
            console.log(`   Found ${response.predictions.length} predictions for "atlanta"`);
          } else {
            console.log('⚠️  Places API returned no results');
          }
        }
      });
    });
  },

  logs: () => {
    console.log('📝 Server logs (last 50 lines):');
    if (fs.existsSync('server.log')) {
      exec('tail -50 server.log', (error, stdout) => {
        if (error) {
          console.log('No logs found');
        } else {
          console.log(stdout);
        }
      });
    } else {
      console.log('No log file found. Run server to generate logs.');
    }
  },

  monitor: () => {
    console.log('📈 Starting real-time monitoring...');
    console.log('Press Ctrl+C to stop monitoring\n');
    
    const monitor = setInterval(() => {
      exec('curl -s http://localhost:3000/health', (error, stdout) => {
        const timestamp = new Date().toISOString();
        if (error) {
          console.log(`[${timestamp}] ❌ Server DOWN`);
        } else {
          console.log(`[${timestamp}] ✅ Server UP`);
        }
      });
    }, 5000);

    process.on('SIGINT', () => {
      clearInterval(monitor);
      console.log('\n🛑 Monitoring stopped');
      process.exit();
    });
  },

  help: () => {
    console.log(`
🏗️  HiPop Server Management Tool

Available commands:
  start     - Start the production server
  dev       - Start development server with auto-reload
  status    - Check if server is running
  test      - Test API endpoints
  logs      - Show recent server logs
  monitor   - Real-time server monitoring
  help      - Show this help message

Usage: node manage.js <command>
Example: node manage.js start
    `);
  }
};

const command = process.argv[2];

if (commands[command]) {
  commands[command]();
} else {
  console.log('❌ Unknown command:', command);
  commands.help();
}