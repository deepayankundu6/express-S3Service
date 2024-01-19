const express = require("express");

const app = express();
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

app.get("/health", (req, res) => {
    console.log("API is Ok");
    res.send({
        status: "API is up and running"
    })
});


module.exports = app;