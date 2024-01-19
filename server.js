const app = require("./routes");
const http = require("http");
const PORT = 5505;
const server = http.createServer(app);

server.listen(PORT, (err) => {
    if (err) console.log("opps some error occured while setting up the server!!!");
    console.log(`Serverl listening on port ${PORT}`);
})
