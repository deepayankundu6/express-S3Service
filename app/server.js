const app = require("./routes");
const http = require("http");
require('dotenv').config();

const PORT = 5505;
const server = http.createServer(app);

server.listen(PORT, (err) => {
    if (err) console.log("opps some error occured while setting up the server!!!");
    console.log(`Server listening on port ${PORT}`);
})
