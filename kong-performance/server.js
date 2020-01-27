var http = require('http');
var fs = require('fs');
var colors = require('colors');

http.createServer(function (req, response) {
    fs.readFile('index.html', 'utf-8', function (err, data) {
        response.writeHead(200, { 'Content-Type': 'text/html' });

        let appRawData = fs.readFileSync('src/results/app.log.json');
        let nginxRawData = fs.readFileSync('src/results/nginx.log.json');
        let kongRawData = fs.readFileSync('src/results/kong.log.json');
        let expressGatewayRawData = fs.readFileSync('src/results/express-gateway.log.json');

        let appDataStr = JSON.parse(appRawData);
        let nginxDataStr = JSON.parse(nginxRawData);
        let kongDataStr = JSON.parse(kongRawData);
        let expressGatewayDataStr = JSON.parse(expressGatewayRawData);

        console.log(appDataStr)

        var appData=appDataStr.map(Number);
        appData.pop()
        var nginxData=nginxDataStr.map(Number);
        nginxData.pop()
        var kongData=kongDataStr.map(Number);
        kongData.pop()
        var expressGatewayData=expressGatewayDataStr.map(Number);
        expressGatewayData.pop()

        var result = data.replace('{{appData}}', JSON.stringify(appData));
        result = result.replace('{{nginxData}}', JSON.stringify(nginxData));
        result = result.replace('{{kongData}}', JSON.stringify(kongData));
        result = result.replace('{{expressGatewayData}}', JSON.stringify(expressGatewayData));
        response.write(result);
        response.end();
    });
}).listen(1337, '127.0.0.1');

console.log('Server running at http://127.0.0.1:1337/');