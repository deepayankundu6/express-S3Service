const AWS = require('aws-sdk');

const saveToS3 = async (bucketName, File) => {
    const S3Agent = new AWS.S3();
    // Set the parameters for the file you want to upload
    const params = {
        Bucket: bucketName,
        Key: File.originalname,
        Body: File.buffer
    };
    let response = {
        status: 200,
        message: "File uploaded successfullt into S3"
    }

    try {
        response = await new Promise((resolve, reject) => {
            S3Agent.upload(params, (err, data) => {
                if (err) {
                    console.log('Error uploading file:', err);
                    reject(err)
                } else {
                    console.log('File uploaded successfully. File location:', data.Location);
                    resolve({
                        status: 200,
                        message: "File uploaded successfully into S3",
                        location: data.Location
                    })
                }
            });
        })

    } catch (error) {
        response = {
            status: 500,
            message: "Unable to uplaod file into S3",
            error: error.message
        }
        return response;
    }



}

module.exports = { saveToS3 };