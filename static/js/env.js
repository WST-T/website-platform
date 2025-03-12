// This script loads environment variables from .env file
(function() {
  window._env_ = {};

  async function loadEnv() {
    try {
      const response = await fetch('/.env');
      if (response.ok) {
        const text = await response.text();

        text.split('\n').forEach(line => {
          const parts = line.split('=');
          if (parts.length === 2) {
            const key = parts[0].trim();
            const value = parts[1].trim();
            window._env_[key] = value;
          }
        });
        console.log('Environment variables loaded successfully');
      }
    } catch (error) {
      console.log('Failed to load environment variables', error);
    }
  }

  loadEnv();
})();
