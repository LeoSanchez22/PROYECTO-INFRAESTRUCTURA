const {
  generatePythonScript,
  writeScriptToFile,
  uploadFileToS3,
  recordExecutionInDynamoDB,
  buildResponse,
  generateS3Key
} = require('../index');

const fs = require('fs');

// Mock fs module
jest.mock('fs');

describe('Pruebas Unitarias - Generador de Horarios Académicos', () => {
  
  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('generatePythonScript', () => {
    test('debería generar un script de Python con el contenido correcto', () => {
      // Arrange
      const executionId = 'test-123';
      const timestamp = '2023-12-01T10:00:00.000Z';

      // Act
      const result = generatePythonScript(executionId, timestamp);

      // Assert
      expect(result).toContain('Hello World! This is an automatically generated academic schedule script.');
      expect(result).toContain(`Execution ID: ${executionId}`);
      expect(result).toContain(`Timestamp: ${timestamp}`);
      expect(result).toContain('class ScheduleGenerator:');
      expect(result).toContain('def add_course(self, course_name, professor, hours):');
      expect(result).toContain('Mathematics 101');
      expect(result).toContain('Computer Science');
      expect(result).toContain('Physics');
    });

    test('debería manejar caracteres especiales en executionId y timestamp', () => {
      // Arrange
      const executionId = 'test-with-special-chars-!@#';
      const timestamp = '2023-12-01T10:00:00.000Z';

      // Act
      const result = generatePythonScript(executionId, timestamp);

      // Assert
      expect(result).toContain(executionId);
      expect(result).toContain(timestamp);
    });
  });

  describe('generateS3Key', () => {
    test('debería generar la clave S3 con el formato correcto', () => {
      // Arrange
      const userId = 'user123';
      const timestamp = '2023-12-01T10:00:00.000Z';
      const executionId = 'exec-456';

      // Act
      const result = generateS3Key(userId, timestamp, executionId);

      // Assert
      expect(result).toBe('schedules/user123/2023-12-01T10:00:00.000Z-exec-456.py');
    });

    test('debería manejar usuario anónimo', () => {
      // Arrange
      const userId = 'anonymous';
      const timestamp = '2023-12-01T10:00:00.000Z';
      const executionId = 'exec-789';

      // Act
      const result = generateS3Key(userId, timestamp, executionId);

      // Assert
      expect(result).toBe('schedules/anonymous/2023-12-01T10:00:00.000Z-exec-789.py');
    });
  });

  describe('writeScriptToFile', () => {
    test('debería escribir el contenido al archivo especificado', () => {
      // Arrange
      const filePath = '/tmp/test-script.py';
      const content = 'print("Hello World")';

      // Act
      writeScriptToFile(filePath, content);

      // Assert
      expect(fs.writeFileSync).toHaveBeenCalledWith(filePath, content);
      expect(fs.writeFileSync).toHaveBeenCalledTimes(1);
    });

    test('debería propagar errores del sistema de archivos', () => {
      // Arrange
      const filePath = '/invalid/path.py';
      const content = 'test content';
      const fsError = new Error('Permission denied');
      
      fs.writeFileSync.mockImplementation(() => {
        throw fsError;
      });

      // Act & Assert
      expect(() => writeScriptToFile(filePath, content)).toThrow('Permission denied');
    });
  });

  describe('uploadFileToS3', () => {
    test('debería subir archivo a S3 correctamente', async () => {
      // Arrange
      const mockS3 = {
        putObject: jest.fn().mockReturnValue({
          promise: jest.fn().mockResolvedValue({})
        })
      };
      
      const bucket = 'test-bucket';
      const key = 'test-key.py';
      const filePath = '/tmp/test.py';
      const fileContent = Buffer.from('test content');
      
      fs.readFileSync.mockReturnValue(fileContent);

      // Act
      const result = await uploadFileToS3(mockS3, bucket, key, filePath);

      // Assert
      expect(fs.readFileSync).toHaveBeenCalledWith(filePath);
      expect(mockS3.putObject).toHaveBeenCalledWith({
        Bucket: bucket,
        Key: key,
        Body: fileContent,
        ContentType: 'text/plain'
      });
      expect(result).toBe('s3://test-bucket/test-key.py');
    });

    test('debería propagar errores de S3', async () => {
      // Arrange
      const s3Error = new Error('S3 upload failed');
      const mockS3 = {
        putObject: jest.fn().mockReturnValue({
          promise: jest.fn().mockRejectedValue(s3Error)
        })
      };
      
      fs.readFileSync.mockReturnValue(Buffer.from('test'));

      // Act & Assert
      await expect(uploadFileToS3(mockS3, 'bucket', 'key', '/path'))
        .rejects.toThrow('S3 upload failed');
    });
  });

  describe('recordExecutionInDynamoDB', () => {
    test('debería registrar ejecución en DynamoDB correctamente', async () => {
      // Arrange
      const mockDynamoDB = {
        put: jest.fn().mockReturnValue({
          promise: jest.fn().mockResolvedValue({})
        })
      };
      
      const tableName = 'test-table';
      const executionData = {
        ExecutionId: 'test-123',
        Status: 'SUCCESS',
        UserId: 'user123'
      };

      // Act
      await recordExecutionInDynamoDB(mockDynamoDB, tableName, executionData);

      // Assert
      expect(mockDynamoDB.put).toHaveBeenCalledWith({
        TableName: tableName,
        Item: executionData
      });
      expect(mockDynamoDB.put).toHaveBeenCalledTimes(1);
    });

    test('debería propagar errores de DynamoDB', async () => {
      // Arrange
      const dbError = new Error('DynamoDB connection failed');
      const mockDynamoDB = {
        put: jest.fn().mockReturnValue({
          promise: jest.fn().mockRejectedValue(dbError)
        })
      };

      // Act & Assert
      await expect(recordExecutionInDynamoDB(mockDynamoDB, 'table', {}))
        .rejects.toThrow('DynamoDB connection failed');
    });
  });

  describe('buildResponse', () => {
    test('debería construir respuesta exitosa correctamente', () => {
      // Arrange
      const status = 'SUCCESS';
      const data = {
        executionId: 'test-123',
        message: 'All good'
      };

      // Act
      const result = buildResponse(status, data);

      // Assert
      expect(result.statusCode).toBe(200);
      expect(JSON.parse(result.body)).toEqual(data);
    });

    test('debería construir respuesta de error correctamente', () => {
      // Arrange
      const status = 'FAILURE';
      const data = {
        executionId: 'test-456',
        errorMessage: 'Something went wrong'
      };

      // Act
      const result = buildResponse(status, data);

      // Assert
      expect(result.statusCode).toBe(500);
      expect(JSON.parse(result.body)).toEqual(data);
    });

    test('debería manejar datos complejos en la respuesta', () => {
      // Arrange
      const status = 'SUCCESS';
      const data = {
        executionId: 'test-789',
        nested: {
          array: [1, 2, 3],
          object: { key: 'value' }
        }
      };

      // Act
      const result = buildResponse(status, data);

      // Assert
      expect(result.statusCode).toBe(200);
      expect(JSON.parse(result.body)).toEqual(data);
    });
  });
});
