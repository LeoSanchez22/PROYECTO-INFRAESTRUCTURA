const { handler } = require('../index');
const AWS = require('aws-sdk');
const fs = require('fs');
const path = require('path');
const { v4: uuidv4 } = require('uuid');

// Mock AWS SDK
jest.mock('aws-sdk');
jest.mock('uuid');
jest.mock('fs');
jest.mock('child_process');

describe('Generador de Horarios Académicos Lambda', () => {
  let mockS3, mockDynamoDB, mockPutObject, mockPut;

  beforeEach(() => {
    // Reset all mocks completely
    jest.resetAllMocks();
    
    // Set environment variables FIRST (before any imports or handler calls)
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
    
    // Mock fs - RESET THESE PROPERLY
    fs.writeFileSync.mockImplementation(() => {});
    fs.readFileSync.mockReturnValue(Buffer.from('mock file content'));
    
    // Clear any cached modules
    delete require.cache[require.resolve('../index')];
  });

  afterEach(() => {
    // Clean up environment variables
    delete process.env.S3_BUCKET_NAME;
    delete process.env.DYNAMODB_TABLE;
  });

  test('debería generar exitosamente el horario para usuario autenticado', async () => {
    // Arrange
    const event = {
      userId: 'user123'
    };
    const context = {};

    // Act
    const result = await handler(event, context);

    // Assert
    expect(result.statusCode).toBe(200);
    
    const responseBody = JSON.parse(result.body);
    expect(responseBody.executionId).toBe('test-uuid-123');
    expect(responseBody.status).toBe('SUCCESS');
    expect(responseBody.s3Location).toContain('s3://test-bucket/schedules/user123/');
    expect(responseBody.errorMessage).toBeNull();

    // Verify S3 interaction
    expect(mockPutObject).toHaveBeenCalledWith({
      Bucket: 'test-bucket',
      Key: expect.stringMatching(/^schedules\/user123\/.*\.py$/),
      Body: expect.any(Buffer),
      ContentType: 'text/plain'
    });

    // Verify DynamoDB interaction
    expect(mockPut).toHaveBeenCalledWith({
      TableName: 'test-table',
      Item: {
        ExecutionId: 'test-uuid-123',
        Timestamp: expect.any(String),
        UserId: 'user123',
        Status: 'SUCCESS',
        S3Location: expect.stringContaining('s3://test-bucket/schedules/user123/'),
        ErrorMessage: null
      }
    });

    // Verify file system operations
    expect(fs.writeFileSync).toHaveBeenCalledWith(
      '/tmp/generated_script.py',
      expect.stringContaining('Hello World! This is an automatically generated academic schedule script.')
    );
  });

  test('debería manejar usuario anónimo cuando no se proporciona userId', async () => {
    // Arrange
    const event = {}; // No userId provided
    const context = {};

    // Act
    const result = await handler(event, context);

    // Assert
    expect(result.statusCode).toBe(200);
    
    const responseBody = JSON.parse(result.body);
    expect(responseBody.status).toBe('SUCCESS');
    expect(responseBody.s3Location).toContain('s3://test-bucket/schedules/anonymous/');

    // Verify S3 key contains 'anonymous'
    expect(mockPutObject).toHaveBeenCalledWith({
      Bucket: 'test-bucket',
      Key: expect.stringMatching(/^schedules\/anonymous\/.*\.py$/),
      Body: expect.any(Buffer),
      ContentType: 'text/plain'
    });

    // Verify DynamoDB record has anonymous user
    expect(mockPut).toHaveBeenCalledWith({
      TableName: 'test-table',
      Item: expect.objectContaining({
        UserId: 'anonymous',
        Status: 'SUCCESS'
      })
    });
  });

  test('debería manejar graciosamente la falla de carga a S3', async () => {
    // Arrange
    const event = { userId: 'user123' };
    const context = {};
    
    const s3Error = new Error('S3 upload failed');
    // Reset the mock to simulate failure
    mockPutObject.mockReset();
    mockPutObject.mockReturnValue({
      promise: jest.fn().mockRejectedValue(s3Error)
    });

    // Act
    const result = await handler(event, context);

    // Assert
    expect(result.statusCode).toBe(500);
    
    const responseBody = JSON.parse(result.body);
    expect(responseBody.status).toBe('FAILURE');
    expect(responseBody.errorMessage).toBe('S3 upload failed');
    expect(responseBody.s3Location).toBeNull();

    // Verify DynamoDB still records the failure
    expect(mockPut).toHaveBeenCalledWith({
      TableName: 'test-table',
      Item: expect.objectContaining({
        Status: 'FAILURE',
        ErrorMessage: 'S3 upload failed',
        S3Location: null
      })
    });
  });

  test('debería manejar error del sistema de archivos durante la generación del script', async () => {
    // Arrange
    const event = { userId: 'user123' };
    const context = {};
    
    const fsError = new Error('Permission denied');
    fs.writeFileSync.mockImplementation(() => {
      throw fsError;
    });

    // Act
    const result = await handler(event, context);

    // Assert
    expect(result.statusCode).toBe(500);
    
    const responseBody = JSON.parse(result.body);
    expect(responseBody.status).toBe('FAILURE');
    expect(responseBody.errorMessage).toBe('Permission denied');

    // Verify S3 upload was not attempted
    expect(mockPutObject).not.toHaveBeenCalled();

    // Verify failure is recorded in DynamoDB
    expect(mockPut).toHaveBeenCalledWith({
      TableName: 'test-table',
      Item: expect.objectContaining({
        Status: 'FAILURE',
        ErrorMessage: 'Permission denied'
      })
    });
  });

  test('debería continuar la ejecución aún si falla el registro en DynamoDB', async () => {
    // Arrange
    const event = { userId: 'user123' };
    const context = {};
    
    const dbError = new Error('DynamoDB connection failed');
    // Reset the mock to simulate failure
    mockPut.mockReset();
    mockPut.mockReturnValue({
      promise: jest.fn().mockRejectedValue(dbError)
    });

    // Act
    const result = await handler(event, context);

    // Assert
    // Function should still return success since main logic succeeded
    expect(result.statusCode).toBe(200);
    
    const responseBody = JSON.parse(result.body);
    expect(responseBody.status).toBe('SUCCESS');
    expect(responseBody.s3Location).toBeTruthy();

    // Verify S3 upload still happened
    expect(mockPutObject).toHaveBeenCalled();
    
    // Verify DynamoDB put was attempted
    expect(mockPut).toHaveBeenCalled();
  });

  test('debería generar contenido válido del script de Python', async () => {
    // Arrange
    const event = { userId: 'testuser' };
    const context = {};

    // Act
    await handler(event, context);

    // Assert
    expect(fs.writeFileSync).toHaveBeenCalled();
    const scriptContent = fs.writeFileSync.mock.calls[0][1];
    
    // Verify script contains expected elements
    expect(scriptContent).toContain('Hello World! This is an automatically generated academic schedule script.');
    expect(scriptContent).toContain('test-uuid-123');
    expect(scriptContent).toContain('class ScheduleGenerator:');
    expect(scriptContent).toContain('def add_course(self, course_name, professor, hours):');
    expect(scriptContent).toContain('Mathematics 101');
    expect(scriptContent).toContain('Computer Science');
    expect(scriptContent).toContain('Physics');
  });
});
