exports.handler = async (event) => {
    // Basic handler for ECS task triggering
    return {
        statusCode: 200,
        body: JSON.stringify('ECS task trigger handler')
    };
};

