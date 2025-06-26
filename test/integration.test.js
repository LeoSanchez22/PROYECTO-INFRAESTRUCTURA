const { handler } = require('../index');
const AWS = require('aws-sdk');
const fs = require('fs');
const { v4: uuidv4 } = require('uuid');

// Mock AWS SDK
jest.mock('aws-sdk');
jest.mock('uuid');
jest.mock('fs');

describe('Pruebas de Integración - Generador de Horarios Académicos Lambda', () => {
  let mockS3, mockDynamoDB, mockPutObject, mockPut;

  beforeEach(() => {
    // Reset all mocks completely
    jest.resetAllMocks();
    
    // Set environment variables
    process.env.S3_BUCKET_NAME = 'test-bucket';
    process.env.DYNAMODB_TABLE = 'test-table';
    
    // Mock S3
    mockPutObject = jest.fn().mockReturnValue({
      promise: jest.fn().mockResolvedValue({})
    });
    mockS3 = {
      putObject: mockPutObject
    };
    
    // Mock DynamoDB
    mockPut = jest.fn().mockReturnValue({
      promise: jest.fn().mockResolvedValue({})
    });
    mockDynamoDB = {
      put: mockPut
    };
    
    // Mock AWS constructors
    AWS.S3.mockImplementation(() => mockS3);
    AWS.DynamoDB.DocumentClient.mockImplementation(() => mockDynamoDB);
    
    // Mock UUID
    uuidv4.mockReturnValue('test-uuid-123');
    
    // Mock fs
    fs.writeFileSync.mockImplementation(() => {});
    fs.readFileSync.mockReturnValue(Buffer.from('mock file content'));
    
    // Clear any cached modules
    delete require.cache[require.resolve('../index')];
  });

  afterEach(() => {
    delete process.env.S3_BUCKET_NAME;
    delete process.env.DYNAMODB_TABLE;
  });

  test('debería completar el flujo completo exitosamente para usuario autenticado', async () => {
    // Arrange
    const event = { userId: 'user123' };
    const context = {};

    // Act
    const result = await handler(event, context);

    // Assert - Verificar respuesta final
    expect(result.statusCode).toBe(200);
    
    const responseBody = JSON.parse(result.body);
    expect(responseBody.executionId).toBe('test-uuid-123');
    expect(responseBody.status).toBe('SUCCESS');
    expect(responseBody.s3Location).toContain('s3://test-bucket/schedules/user123/');
    expect(responseBody.errorMessage).toBeNull();

    // Assert - Verificar que se generó el archivo
    expect(fs.writeFileSync).toHaveBeenCalledWith(
      '/tmp/generated_script.py',
      expect.stringContaining('Hello World! This is an automatically generated academic schedule script.')
    );

    // Assert - Verificar subida a S3
    expect(mockPutObject).toHaveBeenCalledWith({
      Bucket: 'test-bucket',
      Key: expect.stringMatching(/^schedules\/user123\/.*\.py$/),
      Body: expect.any(Buffer),
      ContentType: 'text/plain'
    });

    // Assert - Verificar registro en DynamoDB
    expect(mockPut).toHaveBeenCalledWith({
      TableName: 'test-table',
      Item: expect.objectContaining({
        ExecutionId: 'test-uuid-123',
        UserId: 'user123',
        Status: 'SUCCESS',
        S3Location: expect.stringContaining('s3://test-bucket/schedules/user123/'),
        ErrorMessage: null
      })
    });
  });

  test('debería manejar fallas y mantener consistencia en el estado', async () => {
    // Arrange
    const event = { userId: 'user123' };
    const context = {};
    
    // Simular falla en S3
    const s3Error = new Error('S3 service temporarily unavailable');
    mockPutObject.mockReset();
    mockPutObject.mockReturnValue({
      promise: jest.fn().mockRejectedValue(s3Error)
    });

    // Act
    const result = await handler(event, context);

    // Assert - Verificar respuesta de error
    expect(result.statusCode).toBe(500);
    
    const responseBody = JSON.parse(result.body);
    expect(responseBody.status).toBe('FAILURE');
    expect(responseBody.errorMessage).toBe('S3 service temporarily unavailable');
    expect(responseBody.s3Location).toBeNull();

    // Assert - Verificar que el archivo se generó pero no se subió
    expect(fs.writeFileSync).toHaveBeenCalled();
    expect(mockPutObject).toHaveBeenCalled();

    // Assert - Verificar que DynamoDB registra la falla
    expect(mockPut).toHaveBeenCalledWith({
      TableName: 'test-table',
      Item: expect.objectContaining({
        Status: 'FAILURE',
        ErrorMessage: 'S3 service temporarily unavailable',
        S3Location: null
      })
    });
  });

  test('debería mantener robustez cuando DynamoDB falla pero S3 funciona', async () => {
    // Arrange
    const event = { userId: 'user123' };
    const context = {};
    
    // Simular falla en DynamoDB
    const dbError = new Error('DynamoDB timeout');
    mockPut.mockReset();
    mockPut.mockReturnValue({
      promise: jest.fn().mockRejectedValue(dbError)
    });

    // Act
    const result = await handler(event, context);

    // Assert - La operación principal debe seguir siendo exitosa
    expect(result.statusCode).toBe(200);
    
    const responseBody = JSON.parse(result.body);
    expect(responseBody.status).toBe('SUCCESS');
    expect(responseBody.s3Location).toBeTruthy();

    // Assert - Verificar que S3 funcionó correctamente
    expect(mockPutObject).toHaveBeenCalled();
    
    // Assert - Verificar que DynamoDB falló pero no afectó el resultado
    expect(mockPut).toHaveBeenCalled();
  });
});
