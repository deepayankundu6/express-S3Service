const { S3 } = require('@aws-sdk/client-s3');

const saveToS3 = async (bucketName, File) => {
    const S3Agent = new S3();
    let response;

    const params = {
        Bucket: bucketName,
        Key: `my-uploads/${File.originalname}`,
        Body: File.buffer
    };
    
    try {
        response = await new Promise((resolve, reject) => {
            S3Agent.putObject(params, (err, data) => {
                if (err) {
                    console.log(`Error occured uploading file ${File.originalname}: `, err);
                    reject(err)
                } else {
                    console.log('File uploaded successfully.');
                    resolve({
                        status: 200,
                        message: "File uploaded successfully into S3"
                    })
                }
            });
        })

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