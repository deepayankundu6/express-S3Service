const { PutObjectCommand, S3Client } = require('@aws-sdk/client-s3');

const saveToS3 = async (bucketName, File) => {
    let response;
    const params = {
        Bucket: bucketName,
        Key: `my-uploads/${File.originalname}`,
        Body: File.buffer
    };
    
    try {
        const command = new PutObjectCommand(params);
        const response = await client.send(command);
        return {
            status: 200,
            message: "File uploaded successfully into S3"
        }

    } catch (error) {
        console.log(error);

        response = {
            status: 500,
            message: "Unable to uplaod file into S3",
            error: error.message
        }
    }
    return response;
}

module.exports = { saveToS3 };