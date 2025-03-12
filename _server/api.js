/*

Simple server running on port 3000 that emulates an endpoint api.
That when requesting the root will return the json data feed and
when requesting one of the urls will return that image data

*/
const path = require('path');
const fs = require('fs');
var http = require('http');
var url = require('url');
const data = {
    "products": [
        {"name": "alerts.png", "url": "http://localhost:3000/platform-take-home/alerts.png"},
        {"name": "application-performance-monitoring.png", "url": "http://localhost:3000/platform-take-home/application-performance-monitoring.png"},
        {"name": "database-monitoring.png", "url": "http://localhost:3000/platform-take-home/database-monitoring.png"},
        {"name": "log-management.png", "url": "http://localhost:3000/platform-take-home/log-management.png"},
        {"name": "observability-pipelines.png", "url": "http://localhost:3000/platform-take-home/observability-pipelines.png"},
        {"name": "real-user-monitoring.png", "url": "http://localhost:3000/platform-take-home/real-user-monitoring.png"}
    ]
};
const routes = {
    '/platform-take-home/alerts.png': fs.readFileSync(path.join(__dirname, 'alerts.png')),
    '/platform-take-home/application-performance-monitoring.png': fs.readFileSync(path.join(__dirname, 'application-performance-monitoring.png')),
    '/platform-take-home/database-monitoring.png': fs.readFileSync(path.join(__dirname, 'database-monitoring.png')),
    '/platform-take-home/log-management.png': fs.readFileSync(path.join(__dirname, 'log-management.png')),
    '/platform-take-home/observability-pipelines.png': fs.readFileSync(path.join(__dirname, 'observability-pipelines.png')),
    '/platform-take-home/real-user-monitoring.png': fs.readFileSync(path.join(__dirname, 'real-user-monitoring.png')),
};
const app = http.createServer(function(req, res){
    const parts = url.parse(req.url);
    const route = routes[parts.pathname];
    if(route) {
        res.setHeader('Content-Type', 'image/png');
        res.end(route);
    } else {
        res.setHeader('Content-Type', 'application/json');
        res.end(JSON.stringify(data, null, 3));
    }
});
app.listen(3000);