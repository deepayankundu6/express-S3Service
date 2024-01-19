const express = require("express");
const cookieParser = require('cookie-parser')
const bodyParser = require('body-parser')
const multer = require("multer");
const { saveToS3 } = require("./awsS3")

const initialize = () => {
    const storage = multer.memoryStorage();
    return multer({
        storage,
    })
}

const app = express();
app.use(cookieParser())
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(bodyParser.json())

app.get("/health", (req, res) => {
    console.log("API is Ok");
    res.send({
        status: "API is up and running"
    })
});

app.post("/health", (req, res) => {
    console.log("API is Ok");
    console.log("Paylaod received: ", req.body);
    res.send({
        status: "API is up and running",
        body: req.body
    })
});

app.put("/file/upload", initialize().single("FILE"), async (req, res) => {
    console.log("Received a file: " + req.file.originalname);
    const response = await saveToS3(process.env.BUCKET_NAME, req.file)
    res.status(response.status).send(response);
});

app.put("/files/upload", initialize().array("FILE", 5), (req, res) => {
    console.log("Received a files: " + req.files.length);
    res.send({
        status: "Ok"
    })
});


module.exports = app;