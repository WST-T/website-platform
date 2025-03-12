// Simple function to get environment variables from .env file
const getEnv = (key, defaultValue) => {
  // For browser environments where process.env might not be available
  if (typeof window !== 'undefined' && window._env_ && window._env_[key]) {
    return window._env_[key];
  }
  return defaultValue;
};

(function(h,o,u,n,d) {
  h=h[d]=h[d]||{q:[],onReady:function(c){h.q.push(c)}}
  d=o.createElement(u);d.async=1;d.src=n
  n=o.getElementsByTagName(u)[0];n.parentNode.insertBefore(d,n)
})(window,document,'script','https://www.datadoghq-browser-agent.com/us1/v5/datadog-rum.js','DD_RUM')

window.DD_RUM.onReady(function() {
  window.DD_RUM.init({
    // Use environment variables with fallbacks to hardcoded values
    applicationId: getEnv('DATADOG_APPLICATION_ID'),
    clientToken: getEnv('DATADOG_CLIENT_TOKEN'),
    site: getEnv('DATADOG_SITE'),
    service: 'website-platform',
    env: getEnv('NODE_ENV', 'production'),
    // Specify a version number to identify releases
    version: '1.0.0',
    sessionSampleRate: 100,
    sessionReplaySampleRate: 20,
    trackUserInteractions: true,
    trackResources: true,
    trackLongTasks: true,
    defaultPrivacyLevel: 'mask-user-input'
  });

  // Start tracking
  window.DD_RUM.startSessionReplayRecording();
})
