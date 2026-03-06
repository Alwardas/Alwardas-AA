const http = require('http');

http.get('http://localhost:3001/api/student/profile?userId=f002f1a3-5ff9-4e78-9a14-64878a86c0cb', (res) => {
    let data = '';
    res.on('data', chunk => data += chunk);
    res.on('end', () => console.log(data));
}).on('error', err => console.error(err));
